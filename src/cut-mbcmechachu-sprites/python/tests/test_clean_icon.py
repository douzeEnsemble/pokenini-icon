import pytest
import sh
import os
import sys
from pathlib import Path

from wand.image import Image
from wand.color import Color

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.CleanIconService import CleanIconService
from module.Util.FileDir import FileDir

class TestCleanIconService:
    def test_clean_icon_bulbasaur(self):
        self.__assertCleanup__('icon-0-3', 4339, 285)

    def test_clean_icon_necrozma_ultra(self):
        self.__assertCleanup__('icon-20-2', 3051, 1573)
        
    def test_clean_no_source(self):
        cleanIconService = CleanIconService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            cleanIconService.clean(
                current+'/resources/split_sprites/icon-999999-9999999.png'
            )

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            CleanIconService('nexiste.pas.ini')

    def __assertCleanup__(self, imageName, expectedNbTransparentPixel, expectedNbNotTransparentPixel):
        cleanIconService = CleanIconService('config.test.ini')

        cleanedIconFile = cleanIconService.clean(
            current+'/resources/split_sprites/'+imageName+'.png'
        )

        path = Path(cleanedIconFile)
        assert True == path.is_file()

        with Image(filename=cleanedIconFile) as img:
            assert Color('transparent') == img[0, 0]

        nbTransparentPixel, nbNotTransparentPixel = self.__countTransparentAndNotTransparentsPixels__(
            cleanedIconFile
        )
        
        assert expectedNbTransparentPixel == nbTransparentPixel
        assert expectedNbNotTransparentPixel == nbNotTransparentPixel

    def __countTransparentAndNotTransparentsPixels__(self, imageFile):
        colorTransparent = Color('transparent')

        nbTransparentPixel = 0
        nbNotTransparentPixel = 0
        
        with Image(filename=imageFile) as newImg:
            for row in newImg:
                for col in row:
                    if col == colorTransparent:
                        nbTransparentPixel += 1
                    else:
                        nbNotTransparentPixel += 1

        return nbTransparentPixel, nbNotTransparentPixel
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-clean-icon/'
        
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)