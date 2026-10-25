#!/bin/bash
# Build script to generate an Anaconda package for the led editor

set -e

# Configuration
PACKAGE_NAME="led"
PACKAGE_VERSION=$(grep "AC_INIT" configure.ac | sed -n "s/.*\[\([0-9.]*\)\].*/\1/p")
BUILD_DIR="conda-build"
RECIPE_DIR="${BUILD_DIR}/led"

echo "Building Conda package for ${PACKAGE_NAME} v${PACKAGE_VERSION}"

# Check for conda
if ! command -v conda &> /dev/null; then
    echo "Error: conda is not installed or not in PATH"
    exit 1
fi

# Create build directory structure
mkdir -p "${RECIPE_DIR}"

# Create meta.yaml
cat > "${RECIPE_DIR}/meta.yaml" << 'EOF'
package:
  name: led
  version: {{ environ.get('LED_VERSION') }}

source:
  path: ../..

build:
  number: 0
  skip: true  # [win]

requirements:
  build:
    - {{ compiler('c') }}
    - automake
    - autoconf
    - swig
    - readline
    - libtcl
  host:
    - readline
    - libtcl
  run:
    - readline
    - libtcl

test:
  commands:
    - led -h

about:
  home: https://github.com/j-woz/led
  license: GPL
  license_family: GPL
  summary: "A line editor based on GNU Readline"
  description: |
    led is a line editor based around the GNU Readline library.
    Basically, it is an ed clone with Readline usability.
    The main use case is when you want to quickly open and make a small
    change to a file without opening a full-screen editor.
  doc_url: https://github.com/j-woz/led
  dev_url: https://github.com/j-woz/led

extra:
  recipe-maintainers:
    - j-woz
EOF

# Create build.sh
cat > "${RECIPE_DIR}/build.sh" << 'EOF'
#!/bin/bash

./bootstrap
./configure \
    --prefix=$PREFIX \
    --with-tcl=$PREFIX
make
make install
EOF

chmod +x "${RECIPE_DIR}/build.sh"

# Create build-linux.sh (Linux-specific)
cat > "${RECIPE_DIR}/build-linux.sh" << 'EOF'
#!/bin/bash

export CFLAGS="-I${PREFIX}/include"
export LDFLAGS="-L${PREFIX}/lib -Wl,-rpath -Wl,${PREFIX}/lib"
export LIBS="-lreadline -lhistory -ltcl"

./bootstrap
./configure \
    --prefix=$PREFIX \
    --with-tcl=$PREFIX \
    --with-tcl-lib-dir=$PREFIX/lib
make
make install
EOF

chmod +x "${RECIPE_DIR}/build-linux.sh"

# Create build-osx.sh (macOS-specific)
cat > "${RECIPE_DIR}/build-osx.sh" << 'EOF'
#!/bin/bash

export CFLAGS="-I${PREFIX}/include"
export LDFLAGS="-L${PREFIX}/lib"
export LIBS="-lreadline -lhistory -ltcl"

./bootstrap
./configure \
    --prefix=$PREFIX \
    --with-tcl=$PREFIX \
    --with-tcl-lib-dir=$PREFIX/lib
make
make install
EOF

chmod +x "${RECIPE_DIR}/build-osx.sh"

# Set version environment variable
export LED_VERSION="${PACKAGE_VERSION}"

echo ""
echo "Recipe created in: ${RECIPE_DIR}/"
echo ""
echo "To build the package, run one of:"
echo ""
echo "  Option 1 (Using conda-build directly):"
echo "    conda build ${RECIPE_DIR}"
echo ""
echo "  Option 2 (Using conda-build with custom channel output):"
echo "    conda build ${RECIPE_DIR} --output-folder ./conda-packages"
echo ""
echo "  Option 3 (Using conda-build in test mode):"
echo "    conda build ${RECIPE_DIR} --test"
echo ""
echo "To upload to Anaconda Cloud:"
echo "  anaconda upload ./conda-packages/<platform>/led-${PACKAGE_VERSION}*.tar.bz2"
echo ""
