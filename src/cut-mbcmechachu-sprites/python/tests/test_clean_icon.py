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

    def test_clean_icon_celesteela(self):
        self.__assertCleanup__('icon-20-2', 3051, 1573)

    def test_clean_icon_celesteela(self):
        self.__assertCleanup__('icon-19-76', 3783, 841)

    def test_clean_icon_cyclizar(self):
        self.__assertCleanup__('icon-23-48', 4083, 541)

    def test_clean_icon_duosion(self):
        self.__assertCleanup__('icon-15-39', 4314, 310)

    def test_clean_icon_gossifleur(self):
        self.__assertCleanup__('icon-20-41', 4422, 202)

    def test_clean_icon_grovyle(self):
        self.__assertCleanup__('icon-8-45', 4208, 416)

    def test_clean_icon_kirlia(self):
        self.__assertCleanup__('icon-9-8', 4322, 302)

    def test_clean_icon_lombre(self):
        self.__assertCleanup__('icon-8-75', 4241, 383)

    def test_clean_icon_ralts(self): 
        self.__assertCleanup__('icon-9-7', 4464, 160)

    def test_clean_icon_roseliam(self):
        self.__assertCleanup__('icon-9-53', 4311, 313)

    def test_clean_icon_roseliaf(self):
        self.__assertCleanup__('icon-9-54', 4307, 317)

    def test_clean_icon_shellos_east(self):
        self.__assertCleanup__('icon-11-63', 4390, 234)

    def test_clean_icon_shelmet(self):
        self.__assertCleanup__('icon-16-7', 4461, 163)

    def test_clean_icon_shiftrym(self):
        self.__assertCleanup__('icon-9-1', 3882, 742)

    def test_clean_icon_shiftryf(self):
        self.__assertCleanup__('icon-9-2', 3899, 725)

    def test_clean_icon_solosis(self):
        self.__assertCleanup__('icon-15-38', 4454, 170)

    def test_clean_icon_vivillon_jungle(self):
        self.__assertCleanup__('icon-17-12', 3877, 747)

    def test_clean_icon_wochien(self):
        self.__assertCleanup__('icon-24-6', 3531, 1093)
        
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