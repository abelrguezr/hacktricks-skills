#!/usr/bin/env python3
"""Test script to verify Python basics concepts work correctly."""

import re
from itertools import product, permutations, combinations

def test_strings():
    """Test string operations."""
    assert "a b".split(" ") == ['a', 'b']
    assert " ".join(['a', 'b']) == "a b"
    assert "abcdef".startswith("ab") == True
    assert "abc\n".strip() == "abc"
    assert "apbc".replace("p", "") == "abc"
    assert "a".upper() == "A"
    assert "A".lower() == "a"
    assert "abc".capitalize() == "Abc"
    print("✓ String operations passed")

def test_lists():
    """Test list operations."""
    a = [1, 2, 3]
    b = [4, 5]
    assert a + b == [1, 2, 3, 4, 5]
    b.append(6)
    assert b == [4, 5, 6]
    assert sum([1, 2, 3]) == 6
    assert sorted([1, 43, 5, 3, 21, 4]) == [1, 3, 4, 5, 21, 43]
    print("✓ List operations passed")

def test_tuples():
    """Test tuple operations."""
    t1 = (1, '2', 'three')
    t2 = (5, 6)
    t3 = t1 + t2
    assert t3 == (1, '2', 'three', 5, 6)
    assert list(t2) == [5, 6]
    print("✓ Tuple operations passed")

def test_dicts():
    """Test dictionary operations."""
    d = {1: 'Jan', 2: 'Feb', 'Feb': 2}
    assert d[1] == 'Jan'
    assert d['Feb'] == 2
    assert d.get('nonexistent', 0) == 0
    d.update({'9': 9})
    assert d['9'] == 9
    print("✓ Dictionary operations passed")

def test_sets():
    """Test set operations."""
    myset = set(['a', 'b'])
    myset.add('c')
    assert 'c' in myset
    myset.add('a')  # No duplicate
    assert len(myset) == 3
    myset2 = set([1, 2, 3, 4])
    assert myset.union(myset2) == {'a', 'b', 'c', 1, 2, 3, 4}
    print("✓ Set operations passed")

def test_lambda():
    """Test lambda functions."""
    assert (lambda x, y: x + y)(5, 3) == 8
    assert list(filter(lambda x: x % 3 == 0, [1, 2, 3, 4, 5, 6, 7, 8, 9])) == [3, 6, 9]
    assert sorted(range(-5, 6), key=lambda x: x**2) == [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5]
    print("✓ Lambda functions passed")

def test_regex():
    """Test regular expressions."""
    assert re.search(r"\w", "hola").group() == "h"
    assert re.findall(r"\w", "hola") == ['h', 'o', 'l', 'a']
    assert re.findall(r"\w+(la)", "hola caracola") == ['la', 'la']
    print("✓ Regular expressions passed")

def test_itertools():
    """Test itertools functions."""
    assert list(product([1, 2], [3, 4])) == [(1, 3), (1, 4), (2, 3), (2, 4)]
    assert list(permutations('12', 2)) == [('1', '2'), ('2', '1')]
    assert list(combinations('123', 2)) == [('1', '2'), ('1', '3'), ('2', '3')]
    print("✓ Itertools passed")

def test_generators():
    """Test generators."""
    def myGen(n):
        yield n
        yield n + 1
    
    g = myGen(6)
    assert next(g) == 6
    assert next(g) == 7
    print("✓ Generators passed")

def test_list_comprehensions():
    """Test list comprehensions."""
    mult1 = [x for x in [1, 2, 3, 4, 5, 6, 7, 8, 9] if x % 3 == 0]
    assert mult1 == [3, 6, 9]
    squared = [x**2 for x in range(5)]
    assert squared == [0, 1, 4, 9, 16]
    print("✓ List comprehensions passed")

def main():
    """Run all tests."""
    print("Running Python basics tests...\n")
    test_strings()
    test_lists()
    test_tuples()
    test_dicts()
    test_sets()
    test_lambda()
    test_regex()
    test_itertools()
    test_generators()
    test_list_comprehensions()
    print("\n✅ All tests passed!")

if __name__ == "__main__":
    main()
