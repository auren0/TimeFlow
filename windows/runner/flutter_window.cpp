#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winver.h>
#include <commctrl.h>
#include <commoncontrols.h>
#include <shellapi.h>
#include <shlobj.h>
#include <wincodec.h>

#pragma comment(lib, "windowscodecs.lib")
#pragma comment(lib, "ole32.lib")

#include <algorithm>
#include <cctype>
#include <cstring>
#include <cwctype>
#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::string Utf8FromWide(const std::wstring& input) {
  if (input.empty()) {
    return std::string();
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, input.data(),
                                       static_cast<int>(input.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, input.data(),
                      static_cast<int>(input.size()), result.data(), size,
                      nullptr, nullptr);
  return result;
}

std::wstring BaseName(const std::wstring& path) {
  const size_t slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return path;
  }
  return path.substr(slash + 1);
}

std::wstring WideFromUtf8(const std::string& input) {
  if (input.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, input.data(),
                                       static_cast<int>(input.size()), nullptr,
                                       0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, input.data(), static_cast<int>(input.size()),
                      result.data(), size);
  return result;
}

std::map<std::string, std::wstring> g_app_paths;
std::map<std::string, std::vector<uint8_t>> g_icon_cache;

bool FileExists(const std::wstring& path) {
  return !path.empty() &&
         GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES;
}

std::wstring RegistryAppPath(const std::wstring& executable) {
  const wchar_t* hives[] = {
      L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\",
      L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\App Paths\\"};
  for (const wchar_t* prefix : hives) {
    const std::wstring key = std::wstring(prefix) + executable;
    for (HKEY root : {HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER}) {
      wchar_t buffer[MAX_PATH * 2];
      DWORD size = sizeof(buffer);
      if (RegGetValueW(root, key.c_str(), nullptr, RRF_RT_REG_SZ, nullptr,
                       buffer, &size) != ERROR_SUCCESS) {
        continue;
      }
      std::wstring value(buffer);
      if (value.size() >= 2 && value.front() == L'"' &&
          value.back() == L'"') {
        value = value.substr(1, value.size() - 2);
      }
      if (FileExists(value)) {
        return value;
      }
    }
  }
  return std::wstring();
}

std::wstring LowerWide(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(towlower(c)); });
  return value;
}

std::wstring SearchPathForExecutable(const std::wstring& executable) {
  wchar_t buffer[MAX_PATH * 2];
  const DWORD length =
      SearchPathW(nullptr, executable.c_str(), nullptr,
                  static_cast<DWORD>(sizeof(buffer) / sizeof(wchar_t)), buffer,
                  nullptr);
  if (length > 0 && length < sizeof(buffer) / sizeof(wchar_t)) {
    return std::wstring(buffer, length);
  }
  return std::wstring();
}

std::wstring ShortcutTarget(const std::wstring& path) {
  IShellLinkW* link = nullptr;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_IShellLinkW,
                              reinterpret_cast<void**>(&link)))) {
    return std::wstring();
  }
  std::wstring target;
  IPersistFile* file = nullptr;
  if (SUCCEEDED(link->QueryInterface(IID_IPersistFile,
                                     reinterpret_cast<void**>(&file)))) {
    if (SUCCEEDED(file->Load(path.c_str(), STGM_READ))) {
      wchar_t buffer[MAX_PATH * 2];
      WIN32_FIND_DATAW data;
      std::memset(&data, 0, sizeof(data));
      if (SUCCEEDED(link->GetPath(
              buffer, static_cast<UINT>(sizeof(buffer) / sizeof(wchar_t)),
              &data, SLGP_RAWPATH))) {
        target = buffer;
      }
    }
    file->Release();
  }
  link->Release();
  return target;
}

std::map<std::wstring, std::wstring> g_shortcut_targets;
bool g_shortcuts_scanned = false;

void ScanStartMenuShortcuts() {
  if (g_shortcuts_scanned) return;
  g_shortcuts_scanned = true;

  std::vector<std::filesystem::path> roots;
  const KNOWNFOLDERID* folders[] = {&FOLDERID_Programs,
                                     &FOLDERID_CommonPrograms};
  for (const KNOWNFOLDERID* folder : folders) {
    PWSTR raw = nullptr;
    if (SUCCEEDED(SHGetKnownFolderPath(*folder, 0, nullptr, &raw))) {
      roots.emplace_back(raw);
      CoTaskMemFree(raw);
    }
  }

  for (const std::filesystem::path& root : roots) {
    std::error_code error;
    if (!std::filesystem::exists(root, error)) continue;
    for (std::filesystem::recursive_directory_iterator it(root, error), end;
         it != end; it.increment(error)) {
      if (error) break;
      if (it->path().extension() != L".lnk") continue;
      const std::wstring target = ShortcutTarget(it->path().wstring());
      if (target.empty()) continue;
      g_shortcut_targets.emplace(LowerWide(BaseName(target)), target);
    }
  }
}

std::wstring ResolveAppPath(const std::string& app_id,
                            const std::wstring& provided) {
  if (FileExists(provided)) {
    return provided;
  }
  const auto cached = g_app_paths.find(app_id);
  if (cached != g_app_paths.end() && FileExists(cached->second)) {
    return cached->second;
  }
  std::wstring executable = WideFromUtf8(app_id);
  if (executable.empty()) {
    return std::wstring();
  }
  if (executable.find(L'.') == std::wstring::npos) {
    executable += L".exe";
  }

  // Windows Terminal's process name differs from its launch alias.
  if (LowerWide(executable) == L"windowsterminal.exe") {
    const std::wstring alias = SearchPathForExecutable(L"wt.exe");
    if (!alias.empty()) {
      g_app_paths[app_id] = alias;
      return alias;
    }
  }

  std::wstring path = RegistryAppPath(executable);
  if (!path.empty()) {
    g_app_paths[app_id] = path;
    return path;
  }

  path = SearchPathForExecutable(executable);
  if (!path.empty()) {
    g_app_paths[app_id] = path;
    return path;
  }

  ScanStartMenuShortcuts();
  const auto shortcut = g_shortcut_targets.find(LowerWide(executable));
  if (shortcut != g_shortcut_targets.end() &&
      FileExists(shortcut->second)) {
    g_app_paths[app_id] = shortcut->second;
    return shortcut->second;
  }
  return std::wstring();
}

/// Extracts 32-bit BGRA pixels from an HICON, properly resolving transparency.
/// For modern 32-bit ARGB icons, the alpha channel in hbmColor is preserved.
/// For classic icons without an alpha channel, transparency is derived from
/// the 1-bit mask in hbmMask so transparent regions do not turn black.
std::vector<uint8_t> ExtractBgraFromIcon(HICON icon, int& out_width,
                                         int& out_height) {
  out_width = 0;
  out_height = 0;
  if (icon == nullptr) {
    return {};
  }

  ICONINFO icon_info = {};
  if (!GetIconInfo(icon, &icon_info)) {
    return {};
  }

  // Ensure GDI bitmap handles are deleted when leaving scope.
  struct ScopedBitmap {
    HBITMAP handle;
    ~ScopedBitmap() {
      if (handle != nullptr) {
        DeleteObject(handle);
      }
    }
  } color_guard{icon_info.hbmColor}, mask_guard{icon_info.hbmMask};

  BITMAP bm = {};
  if (icon_info.hbmColor != nullptr) {
    if (GetObject(icon_info.hbmColor, sizeof(bm), &bm) == 0) {
      return {};
    }
  } else if (icon_info.hbmMask != nullptr) {
    if (GetObject(icon_info.hbmMask, sizeof(bm), &bm) == 0) {
      return {};
    }
    bm.bmHeight /= 2;  // Monochrome icon stores mask and XOR in one bitmap.
  } else {
    return {};
  }

  const int width = bm.bmWidth;
  const int height = bm.bmHeight;
  if (width <= 0 || height <= 0 || width > 512 || height > 512) {
    return {};
  }

  out_width = width;
  out_height = height;

  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = width;
  bmi.bmiHeader.biHeight = -height;  // Top-down so first row is at top.
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  std::vector<uint32_t> pixels(static_cast<size_t>(width) * height, 0);
  HDC hdc = GetDC(nullptr);
  if (hdc == nullptr) {
    return {};
  }

  if (icon_info.hbmColor != nullptr) {
    GetDIBits(hdc, icon_info.hbmColor, 0, height, pixels.data(), &bmi,
              DIB_RGB_COLORS);
  }

  // Check whether the color bitmap contains an actual alpha channel.
  bool has_alpha = false;
  if (icon_info.hbmColor != nullptr) {
    for (uint32_t p : pixels) {
      if ((p & 0xFF000000) != 0) {
        has_alpha = true;
        break;
      }
    }
  }

  // If the color bitmap does not provide alpha, derive it from the mask bitmap.
  // In the mask: 0 (black) means opaque, non-zero (white) means transparent.
  if (!has_alpha && icon_info.hbmMask != nullptr) {
    std::vector<uint32_t> mask_pixels(static_cast<size_t>(width) * height, 0);
    GetDIBits(hdc, icon_info.hbmMask, 0, height, mask_pixels.data(), &bmi,
              DIB_RGB_COLORS);

    for (size_t i = 0; i < pixels.size(); ++i) {
      if ((mask_pixels[i] & 0x00FFFFFF) != 0) {
        // Transparent pixel: set both color and alpha to 0.
        pixels[i] = 0;
      } else {
        // Opaque pixel: force alpha to 255.
        pixels[i] |= 0xFF000000;
      }
    }
  }

  ReleaseDC(nullptr, hdc);

  std::vector<uint8_t> bgra(pixels.size() * 4);
  std::memcpy(bgra.data(), pixels.data(), bgra.size());
  return bgra;
}

/// Encodes 32-bit BGRA pixels into PNG using the native Windows Imaging Component.
std::vector<uint8_t> EncodeBgraToPng(int width, int height,
                                     const uint8_t* bgra) {
  if (width <= 0 || height <= 0 || bgra == nullptr) {
    return {};
  }

  const HRESULT co_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool must_uninit = SUCCEEDED(co_hr);

  IWICImagingFactory* factory = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
  if (FAILED(hr) || factory == nullptr) {
    if (must_uninit) CoUninitialize();
    return {};
  }

  IStream* stream = nullptr;
  hr = CreateStreamOnHGlobal(nullptr, TRUE, &stream);
  if (FAILED(hr) || stream == nullptr) {
    factory->Release();
    if (must_uninit) CoUninitialize();
    return {};
  }

  IWICBitmapEncoder* encoder = nullptr;
  hr = factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder);
  if (SUCCEEDED(hr) && encoder != nullptr) {
    hr = encoder->Initialize(stream, WICBitmapEncoderNoCache);
  }

  IWICBitmapFrameEncode* frame = nullptr;
  if (SUCCEEDED(hr) && encoder != nullptr) {
    hr = encoder->CreateNewFrame(&frame, nullptr);
  }
  if (SUCCEEDED(hr) && frame != nullptr) {
    hr = frame->Initialize(nullptr);
  }
  if (SUCCEEDED(hr) && frame != nullptr) {
    hr = frame->SetSize(static_cast<UINT>(width), static_cast<UINT>(height));
  }
  if (SUCCEEDED(hr) && frame != nullptr) {
    WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
    hr = frame->SetPixelFormat(&format);
  }
  if (SUCCEEDED(hr) && frame != nullptr) {
    hr = frame->WritePixels(static_cast<UINT>(height),
                            static_cast<UINT>(width * 4),
                            static_cast<UINT>(width * height * 4),
                            const_cast<BYTE*>(bgra));
  }
  if (SUCCEEDED(hr) && frame != nullptr) {
    hr = frame->Commit();
  }
  if (SUCCEEDED(hr) && encoder != nullptr) {
    hr = encoder->Commit();
  }

  std::vector<uint8_t> result;
  if (SUCCEEDED(hr)) {
    STATSTG stat = {};
    if (SUCCEEDED(stream->Stat(&stat, STATFLAG_NONAME))) {
      const size_t size = static_cast<size_t>(stat.cbSize.QuadPart);
      HGLOBAL hglobal = nullptr;
      if (SUCCEEDED(GetHGlobalFromStream(stream, &hglobal)) &&
          hglobal != nullptr) {
        void* data = GlobalLock(hglobal);
        if (data != nullptr) {
          result.resize(size);
          std::memcpy(result.data(), data, size);
          GlobalUnlock(hglobal);
        }
      }
    }
  }

  if (frame != nullptr) frame->Release();
  if (encoder != nullptr) encoder->Release();
  stream->Release();
  factory->Release();
  if (must_uninit) CoUninitialize();

  return result;
}

/// Fallback 32-bit BMP encoder with explicit alpha channel support via BITMAPV5HEADER.
std::vector<uint8_t> EncodeBgraToBmpV5(int width, int height,
                                       const uint8_t* bgra) {
  if (width <= 0 || height <= 0 || bgra == nullptr) {
    return {};
  }

  BITMAPV5HEADER v5 = {};
  v5.bV5Size = sizeof(BITMAPV5HEADER);
  v5.bV5Width = width;
  v5.bV5Height = -height;  // Top-down.
  v5.bV5Planes = 1;
  v5.bV5BitCount = 32;
  v5.bV5Compression = BI_BITFIELDS;
  v5.bV5RedMask = 0x00FF0000;
  v5.bV5GreenMask = 0x0000FF00;
  v5.bV5BlueMask = 0x000000FF;
  v5.bV5AlphaMask = 0xFF000000;
  v5.bV5CSType = 0x73524742;  // 'sRGB'
  v5.bV5SizeImage = static_cast<DWORD>(width * height * 4);

  BITMAPFILEHEADER bfh = {};
  bfh.bfType = 0x4D42;  // 'BM'
  bfh.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPV5HEADER);
  bfh.bfSize = bfh.bfOffBits + v5.bV5SizeImage;

  std::vector<uint8_t> result(bfh.bfSize);
  std::memcpy(result.data(), &bfh, sizeof(bfh));
  std::memcpy(result.data() + sizeof(bfh), &v5, sizeof(v5));
  std::memcpy(result.data() + bfh.bfOffBits, bgra, v5.bV5SizeImage);
  return result;
}

std::vector<uint8_t> IconForApp(const std::string& app_id,
                                const std::wstring& provided_path) {
  const auto cached = g_icon_cache.find(app_id);
  if (cached != g_icon_cache.end()) {
    return cached->second;
  }

  const std::wstring path = ResolveAppPath(app_id, provided_path);
  if (path.empty()) {
    return std::vector<uint8_t>();
  }

  SHFILEINFOW info;
  std::memset(&info, 0, sizeof(info));
  if (!SHGetFileInfoW(path.c_str(), 0, &info, sizeof(info),
                      SHGFI_ICON | SHGFI_LARGEICON | SHGFI_SYSICONINDEX)) {
    return std::vector<uint8_t>();
  }

  HICON icon = info.hIcon;
  IImageList* image_list = nullptr;
  if (SUCCEEDED(SHGetImageList(SHIL_JUMBO, IID_IImageList,
                               reinterpret_cast<void**>(&image_list))) &&
      image_list != nullptr) {
    HICON large_icon = nullptr;
    if (SUCCEEDED(image_list->GetIcon(info.iIcon, ILD_TRANSPARENT,
                                      &large_icon)) &&
        large_icon != nullptr) {
      if (icon != nullptr) DestroyIcon(icon);
      icon = large_icon;
    }
    image_list->Release();
  } else if (SUCCEEDED(SHGetImageList(SHIL_EXTRALARGE, IID_IImageList,
                                      reinterpret_cast<void**>(&image_list))) &&
             image_list != nullptr) {
    HICON large_icon = nullptr;
    if (SUCCEEDED(image_list->GetIcon(info.iIcon, ILD_TRANSPARENT,
                                      &large_icon)) &&
        large_icon != nullptr) {
      if (icon != nullptr) DestroyIcon(icon);
      icon = large_icon;
    }
    image_list->Release();
  }

  if (icon == nullptr) {
    return std::vector<uint8_t>();
  }

  int width = 0;
  int height = 0;
  std::vector<uint8_t> bgra = ExtractBgraFromIcon(icon, width, height);
  DestroyIcon(icon);

  if (bgra.empty() || width <= 0 || height <= 0) {
    return std::vector<uint8_t>();
  }

  std::vector<uint8_t> bytes = EncodeBgraToPng(width, height, bgra.data());
  if (bytes.empty()) {
    bytes = EncodeBgraToBmpV5(width, height, bgra.data());
  }

  if (!bytes.empty()) {
    g_icon_cache[app_id] = bytes;
  }
  return bytes;
}

std::wstring FileDescription(const std::wstring& path) {
  DWORD handle = 0;
  const DWORD size = GetFileVersionInfoSizeW(path.c_str(), &handle);
  if (size == 0) {
    return std::wstring();
  }
  std::vector<BYTE> data(size);
  if (!GetFileVersionInfoW(path.c_str(), handle, size, data.data())) {
    return std::wstring();
  }

  struct LanguageAndCodePage {
    WORD language;
    WORD code_page;
  };
  LanguageAndCodePage* translation = nullptr;
  UINT translation_size = 0;
  if (!VerQueryValueW(data.data(), L"\\VarFileInfo\\Translation",
                      reinterpret_cast<LPVOID*>(&translation),
                      &translation_size) ||
      translation == nullptr ||
      translation_size < sizeof(LanguageAndCodePage)) {
    return std::wstring();
  }

  wchar_t query[128];
  swprintf_s(query, L"\\StringFileInfo\\%04x%04x\\FileDescription",
             translation[0].language, translation[0].code_page);
  wchar_t* description = nullptr;
  UINT description_size = 0;
  if (!VerQueryValueW(data.data(), query,
                      reinterpret_cast<LPVOID*>(&description),
                      &description_size) ||
      description == nullptr || description_size == 0) {
    return std::wstring();
  }
  return std::wstring(description);
}

std::wstring ProcessPath(DWORD pid) {
  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) {
    return std::wstring();
  }
  wchar_t buffer[MAX_PATH * 2];
  DWORD size = static_cast<DWORD>(sizeof(buffer) / sizeof(wchar_t));
  std::wstring path;
  if (QueryFullProcessImageNameW(process, 0, buffer, &size)) {
    path.assign(buffer, size);
  }
  CloseHandle(process);
  return path;
}

std::wstring WindowTitle(HWND window) {
  const int length = GetWindowTextLengthW(window);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring buffer(length + 1, L'\0');
  GetWindowTextW(window, buffer.data(), length + 1);
  buffer.resize(length);
  return buffer;
}

DWORD IdleSeconds() {
  LASTINPUTINFO info;
  info.cbSize = sizeof(info);
  if (!GetLastInputInfo(&info)) {
    return 0;
  }
  const DWORD tick = GetTickCount();
  return (tick - info.dwTime) / 1000;
}

flutter::EncodableValue ForegroundAppValue() {
  HWND window = GetForegroundWindow();
  if (window == nullptr) {
    return flutter::EncodableValue();
  }

  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  if (pid == 0) {
    return flutter::EncodableValue();
  }

  const std::wstring path = ProcessPath(pid);
  if (path.empty()) {
    return flutter::EncodableValue();
  }

  const std::wstring file_name = BaseName(path);
  std::string app_id = Utf8FromWide(file_name);
  std::transform(app_id.begin(), app_id.end(), app_id.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  if (!app_id.empty()) {
    g_app_paths[app_id] = path;
  }

  std::wstring app_name = FileDescription(path);
  if (app_name.empty()) {
    app_name = file_name;
  }

  flutter::EncodableMap map;
  map[flutter::EncodableValue(std::string("appId"))] =
      flutter::EncodableValue(app_id);
  map[flutter::EncodableValue(std::string("appName"))] =
      flutter::EncodableValue(Utf8FromWide(app_name));
  map[flutter::EncodableValue(std::string("appPath"))] =
      flutter::EncodableValue(Utf8FromWide(path));
  map[flutter::EncodableValue(std::string("windowTitle"))] =
      flutter::EncodableValue(Utf8FromWide(WindowTitle(window)));
  map[flutter::EncodableValue(std::string("idleSeconds"))] =
      flutter::EncodableValue(static_cast<int32_t>(IdleSeconds()));
  return flutter::EncodableValue(map);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  usage_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "timeflow/usage",
          &flutter::StandardMethodCodec::GetInstance());
  usage_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "fetchForegroundApp") {
          result->Success(ForegroundAppValue());
        } else if (call.method_name() == "getAppIcon") {
          std::string app_id;
          std::wstring path;
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments != nullptr) {
            const auto app_it = arguments->find(
                flutter::EncodableValue(std::string("appId")));
            if (app_it != arguments->end()) {
              if (const std::string* value =
                      std::get_if<std::string>(&app_it->second)) {
                app_id = *value;
              }
            }
            const auto path_it = arguments->find(
                flutter::EncodableValue(std::string("path")));
            if (path_it != arguments->end()) {
              if (const std::string* value =
                      std::get_if<std::string>(&path_it->second)) {
                path = WideFromUtf8(*value);
              }
            }
          }
          result->Success(flutter::EncodableValue(
              app_id.empty() ? std::vector<uint8_t>()
                             : IconForApp(app_id, path)));
        } else if (call.method_name() == "hasUsageAccess") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "openUsageAccessSettings") {
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (usage_channel_) {
    usage_channel_->SetMethodCallHandler(nullptr);
    usage_channel_.reset();
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
