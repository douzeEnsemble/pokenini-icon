import pytest
import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.CharacterRecognitionService import CharacterRecognitionService
from module.Util.FileDir import FileDir

class TestCharacterRecognitionService:
    def test_split_number_one_number(self):
        self.__assertNumber('one_number', '358')

    def test_split_number_two_numbers(self):
        self.__assertNumber('two_numbers', '001-03')

    def test_split_number_three_numbers(self):
        self.__assertNumber('three_numbers', '479-09-34')

    def test_split_number_one_number_one_letter(self):
        self.__assertNumber('one_number_one_letter', '256-M')

    def test_split_number_two_numbers_one_letter(self):
        self.__assertNumber('two_numbers_one_letter', '003-01-F')

    def test_split_number_with_question_marks(self):
        self.__assertNumber('with_question_marks', '???-02-01')

    def test_split_number_empty(self):
        self.__assertNumber('empty', '')

    def test_split_number_chain(self):
        characterRecognitionService = CharacterRecognitionService('config.test.ini')
        
        result = characterRecognitionService.read(
            'tests/resources/character_recognition/one_number.png'
        )
        assert '358' == result
        
        result = characterRecognitionService.read(
            'tests/resources/character_recognition/three_numbers.png'
        )
        assert '479-09-34' == result
        
        result = characterRecognitionService.read(
            'tests/resources/character_recognition/empty.png'
        )
        assert '' == result
        
        result = characterRecognitionService.read(
            'tests/resources/character_recognition/with_question_marks.png'
        )
        assert '???-02-01' == result

    def test_split_no_source(self):
        characterRecognitionService = CharacterRecognitionService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            characterRecognitionService.read('nexiste.pas.png')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            CharacterRecognitionService('nexiste.pas.ini') 

    def __assertNumber(self, numberFilename, expectedText):
        characterRecognitionService = CharacterRecognitionService('config.test.ini')
        
        result = characterRecognitionService.read(
            'tests/resources/character_recognition/'+numberFilename+'.png'
        )

        assert expectedText == result