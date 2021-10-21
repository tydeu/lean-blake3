# Lean Config

ifndef LEAN_SYSROOT
LEAN ?= lean
LEANC ?= leanc
LEAN_SYSROOT := $(shell $(LEAN) --print-prefix)
endif

LEANC ?= $(LEAN_SYSROOT)/bin/leanc
LEAN_INCLUDE := $(LEAN_SYSROOT)/include

# Blake Config

BLAKE3_INCLUDE := blake3/c
BLAKE3_CC_FLAGS := -DBLAKE3_NO_SSE2 -DBLAKE3_NO_SSE41 -DBLAKE3_NO_AVX2 -DBLAKE3_NO_AVX512

# OS Config

OS_NAME := ${OS}
ifneq ($(OS_NAME),Windows_NT)
OS_NAME := $(shell uname -s)
endif

ifeq (${OS_NAME},Windows_NT)
SHARED_LIB_EXT := dll
else
SHARED_LIB_EXT := so
endif

# General Config

CC=cc
AR=ar

# Project Settings

OUT=build

PKG=Blake3
SHIM_LIB=blake3-shim.a
PLUGIN_LIB=${PKG}.${SHARED_LIB_EXT}
BLAKE3_LIB=libblake3-c.a

# Build Targets

all: blake3-plugin blake3-lean

blake3-c: ${BLAKE3_LIB}

blake3-shim: ${OUT}/${SHIM_LIB}

blake3-plugin: ${OUT}/${PLUGIN_LIB}

blake3-lean: ${OUT}/src/${PKG}.olean

test: ${OUT}/${PLUGIN_LIB} ${OUT}/src/${PKG}.olean
	LEAN_PATH=${OUT}/src ${LEAN} --plugin ${OUT}/${PLUGIN_LIB} tests/Tests/HashString.lean

clean:
	rm -rf ${OUT}

${OUT} ${OUT}/c ${OUT}/src ${OUT}/blake3:
	mkdir -p $@

${OUT}/c/%.o: c/%.c | ${OUT}/c
	${CC} -o $@ -c $< -I${LEAN_INCLUDE} -I${BLAKE3_INCLUDE}

${OUT}/blake3/%.o: blake3/c/%.c | ${OUT}/blake3
	${CC} -o $@ -c $< ${BLAKE3_CC_FLAGS}

${OUT}/${BLAKE3_LIB}: ${OUT}/blake3/blake3.o ${OUT}/blake3/blake3_dispatch.o ${OUT}/blake3/blake3_portable.o | ${OUT}/blake3
	${AR} rcs $@ $^

${OUT}/src/%.c: src/%.lean | ${OUT}/src
	${LEAN} -c $@ $< -R src

.PRECIOUS: ${OUT}/src/%.c

${OUT}/src/%.o: ${OUT}/src/%.c | ${OUT}/src
	${LEANC} -o $@ -c $<

${OUT}/src/%.olean: src/%.lean | ${OUT}/src
	${LEAN} -o $@ $< -R src

${OUT}/${SHIM_LIB}: ${OUT}/c/blake3-shim.o | ${OUT}/c
	${AR} rcs $@ $^

${OUT}/${PLUGIN_LIB}: ${OUT}/src/${PKG}.o ${OUT}/${SHIM_LIB} ${OUT}/${BLAKE3_LIB} | ${OUT}/src
	${LEANC} -shared -o $@ $^
