# spider

Use at your own risk :^)

```
'h': Left (../) ←
'l': Right (go down/open) →
'j': Down	↓
'k': Up ↑
'c': Create file
'C': Create directoru
'D': Delete item(s)
'f': Fast travel
' ': Mark item
'R': Rename item
'G': Enter git mode (experimental)
'm': Remove all marks
'a': Read MIME data
'p': Paste marked files
'v': Move marked files
```

## How to install

```sh
# Clone the repository and cd into the directory
mkdir build && cd build
cmake ..
make
sudo make install
```

## Dependencies

* ncurses
* libmagic
* libgit2
* c++17

## Todo:

* ~~cmake~~
* ~~clang-tidy~~
* Plugins (git, debug)
* Execute command(s) in background
* ~~Remove use of `system`, replace with something from `exec` family~~
