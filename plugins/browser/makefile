TARGET := browser.so
OUTPUT := ../../bin/spider.d/$(TARGET)
LDLIBS := -lncursesw -lstdc++fs -lmagic -lgit2 
SRC := $(wildcard *.cpp)
OBJ := $(SRC:%.cpp=%.o)
INCDIR := ../../include
CC := g++
CXXFLAGS := -pedantic -Wall -Wextra -Wfloat-equal -Wwrite-strings -Wno-unused-parameter -Wundef -Wcast-qual -Wshadow -Wredundant-decls -std=c++17 -I$(INCDIR) -shared -fPIC
DBGFLAGS := -g
RELEASEFLAGS := -Ofast

all: $(OUTPUT)

debug: CXXFLAGS += $(DBGFLAGS)
debug: $(OUTPUT)

release: 
	$(eval CXXFLAGS += $(RELEASEFLAGS))
	$(CC) -o $(RELEASE) $(SRC) $(LDLIBS) $(CXXFLAGS) 

$(OUTPUT): $(OBJ)
	$(CC) -o $@ $^ $(LDLIBS)  $(CXXFLAGS)

$(OBJ): $(OBJDIR)%.o : $(SRCDIR)%.cpp
	$(CC) -o $@ -c $< $(LDLIBS) $(CXXFLAGS)

.PHONY: clean setup
clean: 
	rm $(OUTPUT) $(OBJ)
