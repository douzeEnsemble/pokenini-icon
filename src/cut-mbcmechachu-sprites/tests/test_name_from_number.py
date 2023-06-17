import pytest
import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.NameFromNumberService import NameFromNumberService
from module.Util.FileDir import FileDir

class TestNameFromNumberService:
    def test_get(self):
        service = NameFromNumberService('config.test.ini')
        
        service.load('tests/resources/name_from_number/uno.csv')

        assert 'bulbasaur' == service.get('001-00')

    def test_get_some(self):
        service = NameFromNumberService('config.test.ini')
        
        service.load('tests/resources/name_from_number/some.csv')

        assert 'bulbasaur' == service.get('001-00')
        assert 'ivysaur' == service.get('002')
        assert 'venusaur-f' == service.get('003-00-F')
        assert 'charizard-mega-x' == service.get('M006-X')
        assert 'blastoise-gmax' == service.get('G009')

    def test_get_missing(self):
        service = NameFromNumberService('config.test.ini')
        
        service.load('tests/resources/name_from_number/uno.csv')

        assert '' == service.get('999-12')
        
    def test_load(self):
        service = NameFromNumberService('config.test.ini')
        
        service.load('tests/resources/name_from_number/uno.csv')

        assert True == service.is_loaded
        assert 1 == len(service.data)
        
    def test_load_empty(self):
        service = NameFromNumberService('config.test.ini')
        
        service.load('tests/resources/name_from_number/empty.csv')

        assert True == service.is_loaded
        assert 0 == len(service.data)

    def test_successive_load(self):
        service = NameFromNumberService('config.test.ini')

        service.load('tests/resources/name_from_number/uno.csv')
        service.load('tests/resources/name_from_number/uno.csv')

        assert True == service.is_loaded
        assert 1 == len(service.data)

    def test_get_before_loading(self):
        service = NameFromNumberService('config.test.ini')

        with pytest.raises(Exception) as e:
            service.get('012-12')

    def test_load_no_existing_file(self):
        service = NameFromNumberService('config.test.ini')

        with pytest.raises(Exception) as e:
            service.load('nexiste.pas.csv')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            NameFromNumberService('nexiste.pas.ini') 
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        tempDir = 'temp/test-pokemon_name/'
        try:
            FileDir.removeFiles(tempDir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(tempDir)
        os.rmdir(tempDir)