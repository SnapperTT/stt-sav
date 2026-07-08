#!/bin/bash
CXX=g++
CXXFLAGS="-O0 -g -Wall -fmax-errors=5 -std=c++17 $1"

# Build FTXUI once.
if [ ! -f ftxui.o ] || [ 3rdParty/ftxui.cpp -nt ftxui.o ]; then
	echo "Compiling FTXUI..."
	$CXX $CXXFLAGS -c 3rdParty/ftxui.cpp -o ftxui.o || exit 1
fi

# Build the inspector.
$CXX inspect.cpp ftxui.o $CXXFLAGS -o inspect && \
./inspect archive-test
