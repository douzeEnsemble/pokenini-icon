import pytest
import os
import sys
from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.NumberService import NumberService
from module.Util.FileDir import FileDir

class TestNumberService:
    def test_process_number(self):
        numberService = NumberService('config.test.ini')
        
        result = numberService.process(
            'tests/resources/number/number-0-3.png',
            'temp/test-number'
        )

        oldPath = Path('tests/resources/number/bw_number-0-3.png')
        assert False == oldPath.is_file()

        assert '001-03' == result

    def test_process_number_new_dir(self):
        numberService = NumberService('config.test.ini')

        tempDir = 'temp/test-number/sub'
        
        result = numberService.process(
            'tests/resources/number/number-20-2.png',
            tempDir
        )

        oldPath = Path('tests/resources/number/bw_number-20-2.png')
        assert False == oldPath.is_file()

        assert '990' == result
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)

    def test_split_no_source(self):
        numberService = NumberService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            numberService.process('tests/resources/sprite-99999-999999.png')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            NumberService('nexiste.pas.ini') 
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-number/'
        
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)
