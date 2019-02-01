TARGET=spider
LIBS=-lncurses -lstdc++fs -std=c++17
CFLAGS=-O3
SRCS=*.cpp
CC=g++

$(TARGET): $(SRCS)
	$(CC) -o $(TARGET) $(SRCS) $(LIBS) $(CFLAGS)

test: $(TARGET)
	./$(TARGET)
