import pytest
import sh

import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Input.ImageFileInput import ImageFileInput
from module.Input.SpritesOutput import SpritesOutput
from module.Input.AreaInput import AreaInput

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

        assert 10 == area.columns
        assert 1 == area.rows

class IestimageFileInput:
    def testOk(self):
        assert True == ImageFileInput.check('requirements-dev.txt')

    def testKO(self):
        with pytest.raises(Exception) as e:
            ImageFileInput.check('requirements-douze.txt')

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