TARGET := spider
RELEASE := $(TARGET)-release
LDLIBS := -lncursesw -lstdc++fs -lmagic -lgit2
CXXFLAGS := -pedantic -Wall -Wextra -Wfloat-equal -Wwrite-strings -Wno-unused-parameter -Wundef -Wcast-qual -Wshadow -Wredundant-decls -std=c++17
DBGFLAGS := -g
RELEASEFLAGS := -Ofast
SRC := $(wildcard *.cpp)
OBJ := $(SRC:%.cpp=%.o)
CC := g++

#release: release $(TARGET)

#debug: debug $(TARGET)
#$(RELEASE): $(SRC)
	#$(CC) -o $@ $(SRC) $(LDLIBS) $(CXXFLAGS) $(RELEASEFLAGS)
all: $(TARGET)

.PHONY: clean
clean: 
	rm $(TARGET) $(OBJ)

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDLIBS)  $(CXXFLAGS)

debug: clean
	$(eval CXXFLAGS += $(DBGFLAGS))
	$(CC) -o $@ $^ $(LDLIBS)  $(CXXFLAGS)

release: 
	$(eval CXXFLAGS += $(RELEASEFLAGS))
	$(CC) -o $(RELEASE) $(SRC) $(LDLIBS) $(CXXFLAGS) 
