import pytest
import sh
import os
import sys
from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.SpritesToIconsService import SpritesToIconsService
from module.Service.SpriteToIconService import SpriteToIconService
from module.Service.NameFromNumberService import NameFromNumberService
from module.Util.FileDir import FileDir

class TestSpritesToIconsService:
    def test_cut_many(self, capsys):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load(current+'/resources/sprites_to_icons/some.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (6, 76) == spritesToIconsService.cut(
            current+'/resources/sprites_to_icons/3cols',
            'regular'
        )

        out, err = capsys.readouterr()
        assert 'Start for 82 sprites\nEnd with 6 done of 82 total\n' == out
        assert '' == err

    def test_cut_some(self, capsys):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load(current+'/resources/sprites_to_icons/some.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (6, 4) == spritesToIconsService.cut(
            current+'/resources/sprites_to_icons/sample',
            'regular'
        )

        out, err = capsys.readouterr()
        assert 'Start for 10 sprites\n1/10\n2/10\n3/10\n4/10\n5/10\n6/10\nEnd with 6 done of 10 total\n' == out
        assert '' == err

    def test_cut_full(self, capsys):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load(current+'/resources/sprites_to_icons/full.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (91, 149) == spritesToIconsService.cut(
            current+'/resources/sprites_to_icons/3rows',
            'regular'
        )

        out, err = capsys.readouterr()
        assert 'Start for 240 sprites\n24/240\n48/240\n72/240\nEnd with 91 done of 240 total\n' == out
        assert '' == err

    def test_cut_no_names(self):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load(current+'/resources/sprites_to_icons/empty.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (0, 10) == spritesToIconsService.cut(
            current+'/resources/sprites_to_icons/sample',
            'regular'
        )

    def test_cut_names_not_loaded(self):
        spritesToIconsService = SpritesToIconsService(
            'config.test.ini', 
            SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
        )
        
        with pytest.raises(Exception) as e:
            spritesToIconsService.cut(
                current+'/resources/sprites_to_icons/sample',
                'regular'
            )

    def test_cut_non_existing_dir(self):
        spritesToIconsService = SpritesToIconsService(
                'config.test.ini', 
                SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
            )
        
        assert (0, 0) == spritesToIconsService.cut('/nexiste/pas','regular')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            SpritesToIconsService(
                'nexiste.pas.ini', 
                SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
            ) 
    
    @pytest.fixture(autouse=True)
    def beforeAndAfterTest(params):
        cropped_image = 'temp/test-image.png'
        cropped_sprite_dir = 'temp/test-sprites'
        split_sprite_dir = 'temp/test-sprites-split'
        number_dir = 'temp/test-number'
        clean_icon_dir = 'temp/test-clean-icon'
        final_base_dir = 'temp/test-final'

        try:
            FileDir.removeFiles(cropped_image)
            FileDir.removeFiles(cropped_sprite_dir)
            FileDir.removeFiles(split_sprite_dir)
            FileDir.removeFiles(number_dir)
            FileDir.removeFiles(clean_icon_dir)
            FileDir.removeFiles(final_base_dir)
        except Exception:
            pass
        
        yield
        
        FileDir.removeFiles(cropped_image)
        FileDir.removeFiles(cropped_sprite_dir)
        FileDir.removeFiles(split_sprite_dir)
        FileDir.removeFiles(number_dir)
        FileDir.removeFiles(clean_icon_dir)
        FileDir.removeFiles(final_base_dir)
        
        os.rmdir(cropped_image)
        os.rmdir(cropped_sprite_dir)
        os.rmdir(split_sprite_dir)
        os.rmdir(number_dir)
        os.rmdir(clean_icon_dir)
        os.rmdir(final_base_dir)