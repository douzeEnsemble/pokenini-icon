import pytest
import os
import sys
from pathlib import Path

from wand.image import Image

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.CropImageService import CropImageService
from module.Util.FileDir import FileDir
from module.Entity.Area.CompleteArea import CompleteArea
from module.Entity.Area.LineArea import LineArea
from module.Entity.Area.SampleArea import SampleArea
from module.Entity.Area.ThreeColumnsArea import ThreeColumnsArea
from module.Entity.Area.ThreeRowsArea import ThreeRowsArea

class TestCropImageService:
    def test_crop_complete(self):
        self.__assertCropSprite(CompleteArea(), 5520, 2425)

    def test_crop_line(self):
        self.__assertCropSprite(LineArea(), 5520, 97)

    def test_crop_sample(self):
        self.__assertCropSprite(SampleArea(), 690, 97)

    def test_crop_three_cols(self):
        self.__assertCropSprite(ThreeColumnsArea(), 207, 2425)

    def test_crop_three_rows(self):
        self.__assertCropSprite(ThreeRowsArea(), 5520, 291)

    def test_crop_no_source(self):
        cropImageService = CropImageService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            cropImageService.crop(
                'resources/sprites-nexiste-pas.png',
                'temp/test-sprites/'
            )

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            CropImageService('nexiste.pas.ini') 

    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-crop-sprites/'
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)

    def __assertCropSprite(self, area, expectedWith, expectedHeight):
        outputImage = 'temp/test-crop-sprites/crop-sprites.png'

        cropImageService = CropImageService('config.test.ini')       

        cropImageService.crop(
            '../resources/regulars.png',
            area,
            outputImage
        ) 

        path = Path(outputImage)
        assert True == path.is_file()

        with Image(filename=outputImage) as image:
            assert expectedWith == image.width
            assert expectedHeight == image.height