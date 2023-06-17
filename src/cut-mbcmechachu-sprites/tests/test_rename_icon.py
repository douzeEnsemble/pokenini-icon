import pytest
import os
import sys
import shutil

from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.RenameIconService import RenameIconService
from module.Util.FileDir import FileDir

class TestRenameIconService:
    def test_rename_icon(self):
        renameIconService = RenameIconService('config.test.ini')
        renameIconService.rename('temp/c_icon-0-3.png', 'douze', 'temp/test-rename')

        pathNewFile = Path('temp/test-rename/douze.png')
        assert True == pathNewFile.is_file()

        pathOldFile = Path('temp/c_icon-0-3.png')
        assert True == pathOldFile.is_file()

    def test_rename_icon_in_new_dir(self):
        tempDir = 'temp/test-rename-bis/sub'
        renameIconService = RenameIconService('config.test.ini')
        renameIconService.rename('temp/c_icon-0-3.png', 'douze', tempDir)

        pathNewFile = Path(tempDir+'/douze.png')
        assert True == pathNewFile.is_file()

        pathOldFile = Path('temp/c_icon-0-3.png')
        assert True == pathOldFile.is_file()
        
        FileDir.removeDir('temp/test-rename-bis')
        
    def test_rename_no_source(self):
        renameIconService = RenameIconService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            renameIconService.rename('temp/c_icon-999999-999999999.png')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            RenameIconService('nexiste.pas.ini')
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-rename/'
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        shutil.copyfile(
            'tests/resources/rename_icon/c_icon-0-3.png', 
            'temp/c_icon-0-3.png',
        )

        try:
            os.remove('temp/douze.png')
        except Exception:
            pass

        yield
        
        try:
            os.remove('temp/douze.png')
        except Exception:
            pass
        
        try:
            os.remove('temp/c_icon-0-3.png')
        except Exception:
            pass
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)