CXX        ?= g++
PKG_CONFIG ?= pkg-config

CXXFLAGS ?= -O2 -g
CXXFLAGS += -std=c++23 -fPIC -shared -fno-gnu-unique -Wall -Wextra
CXXFLAGS += $(shell $(PKG_CONFIG) --cflags hyprland)

LDLIBS += $(shell $(PKG_CONFIG) --libs hyprland)

TARGET := niselle-overview.so
SRC    := src/main.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET) $(LDLIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
