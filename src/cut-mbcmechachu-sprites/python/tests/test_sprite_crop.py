import pytest
import sh
import os
import sys
from pathlib import Path

from wand.image import Image

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.CropSpriteService import CropSpriteService
from module.Util.FileDir import FileDir

class TestCropSpriteService:
    def test_crop_three_cols(self):
        cropSpriteService = CropSpriteService('config.test.ini')       

        cropSpriteService.crop(
            current+'/resources/sprite_crop/sprites-3cols.png',
            'temp/test-sprites/'
        )

        assert 75 == FileDir.countFiles('temp/test-sprites/')

        path = Path('temp/test-sprites/sprite-0-0.png')
        assert True == path.is_file()
        path = Path('temp/test-sprites/sprite-24-2.png')
        assert True == path.is_file()

    def test_crop_sample(self):
        cropSpriteService = CropSpriteService('config.test.ini')       

        cropSpriteService.crop(
            current+'/resources/sprite_crop/sprites-sample.png',
            'temp/test-sprites/'
        )

        assert 10 == FileDir.countFiles('temp/test-sprites/')

        path = Path('temp/test-sprites/sprite-0-0.png')
        assert True == path.is_file()
        path = Path('temp/test-sprites/sprite-0-9.png')
        assert True == path.is_file()

    def test_crop_no_source(self):
        cropSpriteService = CropSpriteService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            cropSpriteService.crop(
                'nexiste.pas.png',
                'temp/test-sprites/'
            )

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            CropSpriteService('nexiste.pas.ini') 

    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-sprites/'
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)