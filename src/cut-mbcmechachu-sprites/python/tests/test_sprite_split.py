import pytest
import sh
import os
import sys
from pathlib import Path

from wand.image import Image

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.SplitSpriteService import SplitSpriteService
from module.Util.FileDir import FileDir

class TestSplitSpriteService:
    def test_split_number(self):
        try:
            FileDir.removeFiles('temp/test-sprites-split/')
        except Exception:
            pass

        splitSpritesService = SplitSpriteService('config.test.ini')
        
        numberFile, iconFile = splitSpritesService.split(
            current+'/resources/sprite_split/sprite-0-3.png',
            'temp/test-sprites-split/'
        )

        assert 2 == FileDir.countFiles('temp/test-sprites-split/')

        path = Path(numberFile)
        assert True == path.is_file()
        path = Path(iconFile)
        assert True == path.is_file()

    def test_split_number_bis(self):
        try:
            FileDir.removeFiles('temp/test-sprites-split/')
        except Exception:
            pass

        splitSpritesService = SplitSpriteService('config.test.ini')
        
        splitSpritesService.split(
            current+'/resources/sprite_split/sprite-20-2.png',
            'temp/test-sprites-split/'
        )

        assert 2 == FileDir.countFiles('temp/test-sprites-split/')

        path = Path('temp/test-sprites-split/number-20-2.png')
        assert True == path.is_file()
        path = Path('temp/test-sprites-split/icon-20-2.png')
        assert True == path.is_file()

    def test_split_no_source(self):
        splitSpritesService = SplitSpriteService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            splitSpritesService.split(
                'nexiste.pas.png',
                'temp/test-sprites-split/'
            )

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            SplitSpriteService('nexiste.pas.ini') 
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-sprites-split/'
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)