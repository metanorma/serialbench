# Windows libxml2 Installation Fix

## Issue

The `libxml-ruby` gem was failing to install on Windows in GitHub Actions for Ruby 3.1 and 3.4 due to missing native libxml2 libraries.

**Error:**
```
extconf failure: Cannot find libxml2.
Install the library or try one of the following options to extconf.rb:
  --with-xml2-config=/path/to/xml2-config
  --with-xml2-dir=/path/to/libxml2
```

**Root Cause:**
The `libxml-ruby` gem requires native C libraries (libxml2) that are not available by default on Windows. The gem's native extension compilation fails because:
1. libxml2 development headers are not found
2. libxml2 shared libraries are not in the system path
3. pkg-config cannot locate the libxml2 package

## Solution

### Approach

Instead of excluding `libxml-ruby` from Windows builds, we install the required native libraries using Chocolatey package manager, which is pre-installed on GitHub Actions Windows runners.

### Implementation

#### 1. New GitHub Actions Workflow (`.github/workflows/windows-setup.yml`)

Created a dedicated Windows workflow that:
- Installs libxml2 via Chocolatey before Ruby setup
- Dynamically locates the libxml2 installation directory
- Configures environment variables (PKG_CONFIG_PATH, PATH)
- Passes library paths to bundler for gem compilation
- Runs tests to verify the setup

Key features:
- **Dynamic path detection**: Uses PowerShell to find the actual libxml2 installation directory
- **Robust configuration**: Sets multiple environment variables to ensure gem compilation succeeds
- **Bundler configuration**: Explicitly passes include and lib paths to the gem build process

#### 2. Documentation (`docs/WINDOWS_SETUP.md`)

Comprehensive guide covering:
- Problem explanation
- Multiple installation options (Chocolatey, vcpkg)
- Step-by-step setup instructions
- Environment variable configuration
- Troubleshooting common issues
- CI/CD integration

## Technical Details

### Chocolatey Package

The libxml2 Chocolatey package installs to:
```
C:\ProgramData\chocolatey\lib\libxml2\tools\libxml2-{version}-win32-x86_64\
```

Required components:
- `bin/` - DLL files (libxml2.dll, etc.)
- `include/libxml2/` - Header files for compilation
- `lib/` - Link libraries and pkg-config files
- `lib/pkgconfig/` - libxml-2.0.pc file

### Environment Variables

The workflow sets:
- `PKG_CONFIG_PATH`: Points to the pkgconfig directory
- `PATH`: Includes the bin directory for DLLs
- `LIBXML2_INCLUDE`: Header file location for gem compilation
- `LIBXML2_LIB`: Library file location for gem compilation

### Bundler Configuration

```powershell
bundle config build.libxml-ruby "--with-xml2-include=<path> --with-xml2-lib=<path>"
```

This passes the library locations directly to the gem's extconf.rb during native extension compilation.

## Testing

The fix can be tested by:

1. **Local Windows testing:**
   ```powershell
   choco install libxml2
   choco install pkgconfiglite
   bundle install
   bundle exec rake spec
   ```

2. **GitHub Actions:**
   - Push changes to trigger the `windows-setup` workflow
   - Verify both Ruby 3.1 and 3.4 builds succeed
   - Check that libxml-ruby tests pass

## Benefits

1. **Complete testing**: Windows builds now test libxml-ruby serializer
2. **No platform exclusions**: Maintains consistency across all platforms
3. **Automated setup**: CI/CD handles installation automatically
4. **Documented process**: Clear guidance for local development

## Alternative Approaches Considered

### 1. Platform-conditional dependency (rejected)
```ruby
spec.add_dependency 'libxml-ruby' unless Gem.win_platform?
```
**Pros:** Simple, no setup required
**Cons:** Reduces test coverage, inconsistent behavior across platforms

### 2. Pre-built binary gems (not available)
The libxml-ruby gem doesn't provide pre-built Windows binaries, requiring source compilation.

### 3. WSL-only testing (rejected)
**Pros:** Linux-like environment
**Cons:** Doesn't test native Windows Ruby installations

## Future Considerations

1. **Caching**: Consider caching the Chocolatey packages to speed up CI runs
2. **Version pinning**: May want to pin libxml2 version for reproducibility
3. **Alternative packages**: Monitor for official pre-built binaries
4. **Ruby 3.2/3.3**: Extend testing to additional Ruby versions if needed

## References

- GitHub Actions issue: https://github.com/metanorma/serialbench/actions/runs/18628094589
- libxml-ruby gem: https://github.com/xml4r/libxml-ruby
- Chocolatey libxml2 package: https://community.chocolatey.org/packages/libxml2
- Windows setup documentation: `docs/WINDOWS_SETUP.md`
