import pytest
import sh

import os
import sys

from wand.image import Image

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.CropSpritesService import CropSpritesService
from module.Entity.Area.SampleArea import SampleArea

class TestSpritesCrop:
    def test_complete(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r', 
            'complete'
        ])
        
        with Image(filename=current+'/../temp/sprites.png') as img:
            assert 5520 == img.width
            assert 2425 == img.height

    def test_line(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r', 
            'line'
        ])
        
        with Image(filename=current+'/../temp/sprites.png') as img:
            assert 5520 == img.width
            assert 97 == img.height

    def test_sample(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r', 
            'sample'
        ])
        
        with Image(filename=current+'/../temp/sprites.png') as img:
            assert 690 == img.width
            assert 97 == img.height

    def test_three_columns(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r', 
            '3cols'
        ])
        
        with Image(filename=current+'/../temp/sprites.png') as img:
            assert 207 == img.width
            assert 2425 == img.height

    def test_three_rows(self):
        output = sh.python([
            'cut-mbcmechachu-sprites.py', 
            '../resources/regulars.png', 
            'r', 
            '3rows'
        ])
        
        with Image(filename=current+'/../temp/sprites.png') as img:
            assert 5520 == img.width
            assert 291 == img.height

class TestCropSpritesService:
    def test_crop(self):
        cropSpritesService = CropSpritesService('config.test.ini')       

        cropSpritesService.crop(
            '../resources/regulars.png', 
            SampleArea(), 
            'temp/test-sprites.png'
        )

        with Image(filename=current+'/../temp/test-sprites.png') as img:
            assert 690 == img.width
            assert 97 == img.height

    def test_crop_no_source(self):
        cropSpritesService = CropSpritesService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            cropSpritesService.crop(
                '../resources/nexistepas.png', 
                SampleArea(), 
                'temp/test-sprites.png'
            )

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            CropSpritesService('nexiste.pas.ini') 