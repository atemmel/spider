TARGET := spider
RELEASE := $(TARGET)-release
LDLIBS := -lncursesw -lstdc++fs -lmagic 
CXXFLAGS := -pedantic -Wall -Wextra -std=c++17
DBGFLAGS := -g
RELEASEFLAGS := -O3
SRC := $(wildcard *.cpp)
OBJ := $(SRC:%.cpp=%.o)
CC := g++

all: debug $(TARGET)
release: $(RELEASE)
clean: rm $(TARGET) $(OBJ)

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDLIBS) 

debug: $(eval CXXFLAGS += $(DBGFLAGS))

$(RELEASE): $(SRC)
	$(CC) -o $@ $(SRC) $(LDLIBS) $(CXXFLAGS) $(RELEASEFLAGS)

