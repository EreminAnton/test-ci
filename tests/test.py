a = 1 
b = 2
c = 3
d = 1

def test():
    assert a == b is False
    assert a == d is True
    assert a == c is False
    