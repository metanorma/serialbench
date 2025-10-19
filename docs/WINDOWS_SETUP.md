# Windows Setup Guide for Serialbench

This guide explains how to set up serialbench on Windows, particularly for installing the `libxml-ruby` gem which requires native libxml2 libraries.

## Problem

The `libxml-ruby` gem requires native C libraries (libxml2) that need to be installed separately on Windows. Without these libraries, bundler will fail when trying to install the gem.

## Solution

### Option 1: Using Chocolatey (Recommended)

1. Install [Chocolatey](https://chocolatey.org/install) if you haven't already:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

2. Install libxml2 and required tools:

```powershell
choco install -y libxml2
choco install -y pkgconfiglite
```

3. Set environment variables (you may need to adjust paths based on your installation):

```powershell
# Find the actual libxml2 installation path
$libxmlPath = (Get-ChildItem "C:\ProgramData\chocolatey\lib\libxml2" -Recurse -Filter "libxml2.dll" | Select-Object -First 1).Directory.Parent.FullName

# Set PKG_CONFIG_PATH
$env:PKG_CONFIG_PATH = "$libxmlPath\lib\pkgconfig"
[System.Environment]::SetEnvironmentVariable('PKG_CONFIG_PATH', $env:PKG_CONFIG_PATH, 'User')

# Add to PATH
$env:PATH = "$libxmlPath\bin;$env:PATH"
$currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
[System.Environment]::SetEnvironmentVariable('PATH', "$libxmlPath\bin;$currentPath", 'User')
```

4. Install Ruby dependencies:

```powershell
bundle install
```

### Option 2: Using vcpkg

1. Install vcpkg:

```powershell
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```

2. Install libxml2:

```powershell
.\vcpkg install libxml2:x64-windows
```

3. Set environment variables:

```powershell
$vcpkgPath = "C:\path\to\vcpkg\installed\x64-windows"
$env:PKG_CONFIG_PATH = "$vcpkgPath\lib\pkgconfig"
$env:PATH = "$vcpkgPath\bin;$env:PATH"
```

### Option 3: Skip libxml-ruby (Testing Only)

If you don't need to test the libxml serializer, you can temporarily exclude it:

```ruby
# In Gemfile or when installing
bundle install --without libxml
```

Or remove it from the gemspec temporarily (not recommended for CI).

## Troubleshooting

### Error: "Cannot find libxml2"

This means the libxml2 libraries are not in the expected locations. Try:

1. Verify libxml2 is installed:
```powershell
where libxml2.dll
```

2. Check pkg-config can find it:
```powershell
pkg-config --libs libxml-2.0
```

3. Manually specify the path when installing the gem:
```powershell
gem install libxml-ruby -- --with-xml2-dir="C:\path\to\libxml2"
```

### Error: "mkmf.log shows missing headers"

The development headers aren't found. Make sure you installed the complete libxml2 package including headers.

## GitHub Actions CI

For CI/CD on GitHub Actions, see `.github/workflows/windows-setup.yml` for the complete setup that:

1. Installs libxml2 via Chocolatey
2. Configures environment paths
3. Runs bundle install
4. Executes tests

## Local Development

For local development on Windows, follow the Chocolatey or vcpkg installation steps above. There is no automated Rake task - you must manually install libxml2 before running `bundle install`.
