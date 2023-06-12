import pytest
import os
import sys
from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.SpriteToIconService import SpriteToIconService
from module.Service.NameFromNumberService import NameFromNumberService
from module.Util.FileDir import FileDir

class TestSpriteToIconService:
    def test_transform_name_not_found(self):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load(current+'/resources/sprite_to_icon/some.csv')

        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        
        assert True == spriteToIconService.transform(
            current+'/resources/sprite_to_icon/sprite-0-6.png',
            'regular'
        )

        iconPath = Path('temp/test-final/regular/venusaur-f.png')
        
        assert True == iconPath.is_file()

    def test_transform_name_not_found(self):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load(current+'/resources/sprite_to_icon/some.csv')

        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        
        assert False == spriteToIconService.transform(
            current+'/resources/sprite_to_icon/sprite-0-3.png',
            'regular'
        )

    def test_transform_no_names(self):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load(current+'/resources/sprite_to_icon/empty.csv')

        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        
        assert False == spriteToIconService.transform(
            current+'/resources/sprite_to_icon/sprite-0-3.png',
            'regular'
        )

    def test_transform_names_not_loaded(self):
        spriteToIconService = SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
        
        with pytest.raises(Exception) as e:
            spriteToIconService.transform(
                current+'/resources/sprite_to_icon/sprite-0-3.png',
                'regular'
            )

    def test_transform_no_source(self):
        spriteToIconService = SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
        
        with pytest.raises(Exception) as e:
            spriteToIconService.transform(
                'nexiste.pas.png',
                '/quelque/part'
            )

    def test_transform_no_source(self):
        spriteToIconService = SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
        
        with pytest.raises(Exception) as e:
            spriteToIconService.transform(
                'nexiste.pas.png',
                '/quelque/part'
            )

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            SpriteToIconService('nexiste.pas.ini', NameFromNumberService('config.test.ini')) 
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        cropped_sprite_dir = 'temp/test-sprites'
        split_sprite_dir = 'temp/test-sprites-split'
        number_dir = 'temp/test-number'
        clean_icon_dir = 'temp/test-clean-icon'
        final_base_dir = 'temp/test-final'

        try:
            FileDir.removeFiles(cropped_sprite_dir)
            FileDir.removeFiles(split_sprite_dir)
            FileDir.removeFiles(number_dir)
            FileDir.removeFiles(clean_icon_dir)
            FileDir.removeFiles(final_base_dir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(cropped_sprite_dir)
        FileDir.removeFiles(split_sprite_dir)
        FileDir.removeFiles(number_dir)
        FileDir.removeFiles(clean_icon_dir)
        FileDir.removeFiles(final_base_dir)
        
        os.rmdir(cropped_sprite_dir)
        os.rmdir(split_sprite_dir)
        os.rmdir(number_dir)
        os.rmdir(clean_icon_dir)
        os.rmdir(final_base_dir)