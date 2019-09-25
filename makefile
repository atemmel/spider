TARGET := spider
RELEASE := $(TARGET)-release
LDLIBS := -lncursesw -lstdc++fs -lmagic -lgit2 -ldl
OBJDIR := bin
INCDIR := include
SRCDIR := src
PLUGINDIR := $(OBJDIR)/spider.d
SRC := $(wildcard $(SRCDIR)/*.cpp) $(wildcard $(SRCDIR)/*/*.cpp)
OBJ := $(subst $(SRCDIR),$(OBJDIR),$(SRC:%.cpp=%.o))
CC := g++
CXXFLAGS := -pedantic -Wall -Wextra -Wfloat-equal -Wwrite-strings -Wno-unused-parameter -Wundef -Wcast-qual -Wshadow -Wredundant-decls -std=c++17 -I$(INCDIR)
DBGFLAGS := -g -DDEBUG
RELEASEFLAGS := -Ofast

TARGET := $(OBJDIR)/$(TARGET)
RELEASE := $(OBJDIR)/$(RELEASE)

all: $(TARGET)

debug: CXXFLAGS += $(DBGFLAGS)
debug: $(TARGET)

release: 
	$(eval CXXFLAGS += $(RELEASEFLAGS))
	$(CC) -o $(RELEASE) $(SRC) $(LDLIBS) $(CXXFLAGS) 

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDLIBS)  $(CXXFLAGS)

$(OBJ): $(OBJDIR)%.o : $(SRCDIR)%.cpp
	$(CC) -o $@ -c $< $(LDLIBS) $(CXXFLAGS)

.PHONY: clean setup
clean: 
	rm $(TARGET) $(OBJ)

setup:
	-mkdir $(OBJDIR)
	-mkdir $(PLUGINDIR)

tidy:
	./tools/tidy
