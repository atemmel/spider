#!/bin/python
validTokens = ["set", "bind", "exec"]
validSettings = ["visual", "terminal"]

validTokens.sort()
validSettings.sort()

def print_range(elements):
    for i in range(0, len(elements) ):
        if(i != len(elements) - 1):
            print('"', elements[i], '", ', sep='', end='')
        else:
            print('"', elements[i],'"', sep='' )


print("validTokens:")
print_range(validTokens)
print("validSettings:")
print_range(validSettings)
