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

from module.Service.NumberService import NumberService

class TestNumberService:
    def test_process_number(self):
        numberService = NumberService('config.test.ini')
        
        result = numberService.process(current+'/resources/split_sprites/number-0-3.png')

        assert '001-03' == result

    def test_process_number_bis(self):
        numberService = NumberService('config.test.ini')
        
        result = numberService.process(current+'/resources/split_sprites/number-20-2.png')

        assert 'U800' == result

    def test_split_no_source(self):
        numberService = NumberService('config.test.ini')
        
        with pytest.raises(Exception) as e:
            numberService.process(current+'/resources/sprite-99999-999999.png')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            NumberService('nexiste.pas.ini') 
