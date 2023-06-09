import pytest
import sh
import os
import sys
from pathlib import Path

from wand.image import Image

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.CharacterRecognitionService import CharacterRecognitionService
from module.Util.FileDir import FileDir

class TestCharacterRecognitionService:
    def test_split_number_red(self):
        self.__assertNumbe('bw_number-0-3', '001-03')

    def test_split_number_orange(self):
        self.__assertNumbe('bw_number-7-70', '215-00-00-F')

    def test_split_number_yellow(self):
        self.__assertNumbe('bw_number-9-13', '283')

    def test_split_number_green(self):
        self.__assertNumbe('bw_number-11-63', '422-01')

    def test_split_number_cyan(self):
        self.__assertNumbe('bw_number-16-48', '646-02-01')

    def test_split_number_blue(self):
        self.__assertNumbe('bw_number-17-33', '671-04')

    def test_split_number_purple(self):
        self.__assertNumbe('bw_number-20-2', 'U800')

    def test_split_number_pink(self):
        self.__assertNumbe('bw_number-20-38', 'G826')

    def test_split_number_violet(self):
        self.__assertNumbe('bw_number-24-13', '1007-01')

    def test_split_number_violet_questionmarks(self):
        self.__assertNumbe('bw_number-24-22', '1???')

    def test_split_number_white_questionmarks_and_zeros(self):
        self.__assertNumbe('bw_number-24-23', '???-00-00')

    def test_split_number_white_questionmarks(self):
        self.__assertNumbe('bw_number-24-35', '???')

    def test_split_number_empty(self):
        self.__assertNumbe('bw_number-24-36', '')

    def test_split_number_venusaur_f(self):
        self.__assertNumbe('bw_number-0-10', '003-01-F')

    def test_split_number_mega_charizard_y(self):
        self.__assertNumbe('bw_number-0-19', 'M006-Y')

    def test_split_number_chain(self):
        characterRecognitionService = CharacterRecognitionService('config.test.ini')
        
        result = characterRecognitionService.read(
            current+'/resources/character_recognition/bw_number-9-13.png'
        )
        assert '283' == result
        
        result = characterRecognitionService.read(
            current+'/resources/character_recognition/bw_number-0-10.png'
        )
        assert '003-01-F' == result
        
        result = characterRecognitionService.read(
            current+'/resources/character_recognition/bw_number-0-19.png'
        )
        assert 'M006-Y' == result
        
        result = characterRecognitionService.read(
            current+'/resources/character_recognition/bw_number-20-2.png'
        )
        assert 'U800' == result

    def test_split_no_source(self):
        characterRecognitionService = CharacterRecognitionService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            characterRecognitionService.read('nexiste.pas.png')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            CharacterRecognitionService('nexiste.pas.ini') 

    def __assertNumbe(self, numberFilename, expectedText):
        characterRecognitionService = CharacterRecognitionService('config.test.ini')
        
        result = characterRecognitionService.read(
            current+'/resources/character_recognition/'+numberFilename+'.png'
        )

        assert expectedText == result