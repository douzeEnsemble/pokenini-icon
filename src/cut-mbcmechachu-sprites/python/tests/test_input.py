import pytest
import sh

import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Input.SpriteFileInput import SpriteFileInput
from module.Input.SpritesOutput import SpritesOutput
from module.Input.AreaInput import AreaInput

class TestInputCli:
    def test_args(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r', 
            'sample'
        ])
        
        assert "Cut will be for an area of 10x1 sprites from ../resources/regulars.png into regular/regulars" in output

    def test_bad_file_args(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            'doesnt-exists.png', 
            'r', 
            'sample'
        ])

        assert 'Input file doesnt-exists.png not found' in output

    def test_bad_output_args(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'a', 
            'sample'
        ])

        assert 'R (for regular) or S (for shiny) you must choose, "a" given' in output

    def test_bad_dimension_args(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r', 
            'test'
        ])

        assert "Cut will be for an area of 80x25 sprites from ../resources/regulars.png into regular/regulars" in output

    def test_zero_args(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py'
        ])

        assert 'list index out of range' in output

    def test_one_args(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png'
        ])

        assert 'list index out of range' in output

    def test_two_args(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r'
        ])

        assert 'list index out of range' in output

class TestAreaInput:
    def testComplete(self):
        area = AreaInput.get('complete')

        assert 80 == area.columns
        assert 25 == area.rows

    def testLine(self):
        area = AreaInput.get('line')

        assert 80 == area.columns
        assert 1 == area.rows

    def testSample(self):
        area = AreaInput.get('sample')

        assert 10 == area.columns
        assert 1 == area.rows

    def testThreeColumns(self):
        area = AreaInput.get('3cols')

        assert 3 == area.columns
        assert 25 == area.rows

    def testThreeRows(self):
        area = AreaInput.get('3rows')

        assert 80 == area.columns
        assert 3 == area.rows

    def testDefault(self):
        area = AreaInput.get('default-undefined-value')

        assert 80 == area.columns
        assert 25 == area.rows

class TestSpriteFileInput:
    def testOk(self):
        assert True == SpriteFileInput.check('requirements-dev.txt')

    def testKO(self):
        with pytest.raises(Exception) as e:
            SpriteFileInput.check('requirements-douze.txt')

class TestSpritesOutput:
    def testOk(self):
        spritesOutput = SpritesOutput.get('r')

        assert 'regular' == spritesOutput.dir
        assert 'regulars' == spritesOutput.origin

    def testShiny(self):
        spritesOutput = SpritesOutput.get('s')

        assert 'shiny' == spritesOutput.dir
        assert 'shinies' == spritesOutput.origin

    def testUpperRegular(self):
        spritesOutput = SpritesOutput.get('R')

        assert 'regular' == spritesOutput.dir
        assert 'regulars' == spritesOutput.origin

    def testUnknown(self):
        with pytest.raises(Exception) as e:
            SpritesOutput.get('X')