import pytest
import os
import sys
import shutil

from wand.image import Image
from wand.color import Color

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.ToWebpService import ToWebpService
from module.Util.FileDir import FileDir

class TestToWebpService:        
    def test_convert(self):
        webpService = ToWebpService('config.test.ini')
        
        shutil.copy(
            'tests/resources/to_webp/image.png',
            'temp/test-towebp/image.png'
        )
        
        webpService.convert('temp/test-towebp/image.png')

        assert 2 == FileDir.countFiles('temp/test-towebp')
        assert 1 == FileDir.countFilesWithExtension('temp/test-towebp', '.png')
        assert 1 == FileDir.countFilesWithExtension('temp/test-towebp', '.webp')

    def test_convert_no_source(self):
        webpService = ToWebpService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            webpService.convert('nexiste.pas.png')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            ToWebpService('nexiste.pas.ini') 
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-towebp/'
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)