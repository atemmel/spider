TARGET := spider
RELEASE := $(TARGET)-release
LDLIBS := -lncursesw -lstdc++fs -lmagic -lgit2
CXXFLAGS := -pedantic -Wall -Wextra -Wfloat-equal -Wwrite-strings -Wno-unused-parameter -Wundef -Wcast-qual -Wshadow -Wredundant-decls -std=c++17
DBGFLAGS := -g
RELEASEFLAGS := -Ofast
SRC := $(wildcard *.cpp)
OBJ := $(SRC:%.cpp=%.o)
CC := g++

all: $(TARGET)

debug: $(OBJ)
	$(eval CXXFLAGS += $(DBGFLAGS))
	$(CC) -o $(TARGET) $^ $(LDLIBS)  $(CXXFLAGS)

release: 
	$(eval CXXFLAGS += $(RELEASEFLAGS))
	$(CC) -o $(RELEASE) $(SRC) $(LDLIBS) $(CXXFLAGS) 

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDLIBS)  $(CXXFLAGS)

.PHONY: clean
clean: 
	rm $(TARGET) $(OBJ)
