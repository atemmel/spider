TARGET=spider
LIBS=-lncursesw -lstdc++fs -lmagic -std=c++17
CFLAGS=-O3 -pedantic -Wall -Wextra
SRCS=*.cpp
CC=g++

$(TARGET): $(SRCS)
	$(CC) -o $(TARGET) $(SRCS) $(LIBS) $(CFLAGS)

test: $(TARGET)
	./$(TARGET)
