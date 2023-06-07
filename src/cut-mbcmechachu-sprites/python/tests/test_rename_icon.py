import pytest
import sh
import os
import sys
import shutil

from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.RenameIconService import RenameIconService

class TestRenameIconService:
    def test_rename_icon(self):
        shutil.copyfile(
            current+'/resources/c_icon-0-3.png', 
            'temp/c_icon-0-3.png'
        )

        renameIconService = RenameIconService('config.test.ini')
        renameIconService.rename('temp/c_icon-0-3.png', 'douze')

        pathNewFile = Path('temp/douze.png')
        assert True == pathNewFile.is_file()

        pathOldFile = Path('temp/c_icon-0-3.png')
        assert False == pathOldFile.is_file()
        
    def test_rename_no_source(self):
        renameIconService = RenameIconService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            renameIconService.rename('temp/c_icon-999999-999999999.png')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            RenameIconService('nexiste.pas.ini')
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        try:
            os.remove('douze.png')
        except Exception:
            pass

        yield
        
        try:
            os.remove('c_icon-0-3.png')
            os.remove('douze.png')
        except Exception:
            pass