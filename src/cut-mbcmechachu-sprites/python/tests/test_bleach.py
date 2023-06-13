import pytest
import os
import sys

from wand.image import Image
from wand.color import Color

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.BleachService import BleachService
from module.Util.FileDir import FileDir

class TestBleachService:
    def test_split_number_red(self):
        self.__assertPixelsCount('number-0-3', 83, 527)

    def test_split_number_orange(self):
        self.__assertPixelsCount('number-7-70', 139, 471)

    def test_split_number_yellow(self):
        self.__assertPixelsCount('number-9-13', 49, 561)

    def test_split_number_green(self):
        self.__assertPixelsCount('number-11-63', 78, 532)

    def test_split_number_cyan(self):
        self.__assertPixelsCount('number-16-48', 120, 490)

    def test_split_number_blue(self):
        self.__assertPixelsCount('number-17-33', 78, 532)

    def test_split_number_purple(self):
        self.__assertPixelsCount('number-20-2', 72, 538)

    def test_split_number_pink(self):
        self.__assertPixelsCount('number-20-38', 70, 540)

    def test_split_number_white(self):
        self.__assertPixelsCount('number-24-23', 114, 496)

    def test_split_number_empty(self):
        self.__assertPixelsCount('number-24-36', 0, 610)
        
    def test_split_no_source(self):
        bleachService = BleachService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            bleachService.bleach(
                'nexiste.pas.png',
                'temp/test-bleach/bwnumber-99999-999999.png'
            )

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            BleachService('nexiste.pas.ini') 
    
    def __assertPixelsCount(
            self, 
            numberFilename, 
            expectedNbBlackPixel, 
            expectedNbWhitePixel
    ):
        bleachService = BleachService('config.test.ini')
        
        bleachService.bleach(
            'tests/resources/bleach/'+numberFilename+'.png',
            'temp/test-bleach/bw'+numberFilename+'.png'
        )

        nbBlackPixel, nbWhitePixel, nbOtherColorsPixel = self.__countBlackWhiteAndOthersColors__(
            'temp/test-bleach/bw'+numberFilename+'.png'
        )

        assert expectedNbBlackPixel == nbBlackPixel
        assert expectedNbWhitePixel == nbWhitePixel
        assert 0 == nbOtherColorsPixel

    def __countBlackWhiteAndOthersColors__(self, imageFile):
        colorBlack = Color('#000')
        colorWhite = Color('#fff')

        nbBlackPixel = 0
        nbWhitePixel = 0
        nbOtherColorsPixel = 0
        
        with Image(filename=imageFile) as newImg:
            for row in newImg:
                for col in row:
                    if col == colorBlack:
                        nbBlackPixel += 1
                    elif col == colorWhite:
                        nbWhitePixel += 1
                    else:
                        nbOtherColorsPixel += 1

        return nbBlackPixel, nbWhitePixel, nbOtherColorsPixel
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-bleach/'
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)