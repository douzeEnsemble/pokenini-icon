import pytest
import os
import sys

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
        nameFromNumberService.load('tests/resources/sprites_to_icons/some.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (2, 80) == spritesToIconsService.cut(
            'tests/resources/sprites_to_icons/many',
            'regular'
        )

        expectedOut = """Start for 82 sprites
8/82
16/82
24/82
32/82
40/82
48/82
56/82
64/82
72/82
80/82
End with 2 done of 82 total
"""

        out, err = capsys.readouterr()
        assert expectedOut == out
        assert '' == err

        assert 2 == FileDir.countFiles('temp/test-final/small/numbered_regular')
        
        assert 4 == FileDir.countFiles('temp/test-final/small/regular')
        assert 2 == FileDir.countFilesWithExtension('temp/test-final/small/regular', '.png')
        assert 2 == FileDir.countFilesWithExtension('temp/test-final/small/regular', '.webp')

    def test_cut_some(self, capsys):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load('tests/resources/sprites_to_icons/some.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (2, 8) == spritesToIconsService.cut(
            'tests/resources/sprites_to_icons/some',
            'regular'
        )

        expectedOut = """Start for 10 sprites
1/10
2/10
3/10
4/10
5/10
6/10
7/10
8/10
9/10
10/10
End with 2 done of 10 total
"""

        out, err = capsys.readouterr()
        assert expectedOut == out
        assert '' == err

        assert 2 == FileDir.countFiles('temp/test-final/small/numbered_regular')

        assert 4 == FileDir.countFiles('temp/test-final/small/regular')
        assert 2 == FileDir.countFilesWithExtension('temp/test-final/small/regular', '.png')
        assert 2 == FileDir.countFilesWithExtension('temp/test-final/small/regular', '.webp')

    def test_cut_full(self, capsys):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load('tests/resources/sprites_to_icons/full.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (90, 150) == spritesToIconsService.cut(
            'tests/resources/sprites_to_icons/full',
            'regular'
        )
        expectedOut = """Start for 240 sprites
24/240
48/240
72/240
96/240
120/240
144/240
168/240
192/240
216/240
240/240
End with 90 done of 240 total
"""

        out, err = capsys.readouterr()
        assert expectedOut == out
        assert '' == err

        assert 90 == FileDir.countFiles('temp/test-final/small/numbered_regular')
        
        assert 180 == FileDir.countFiles('temp/test-final/small/regular')
        assert 90 == FileDir.countFilesWithExtension('temp/test-final/small/regular', '.png')
        assert 90 == FileDir.countFilesWithExtension('temp/test-final/small/regular', '.webp')

    def test_cut_few(self, capsys):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load('tests/resources/sprites_to_icons/empty.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)

        assert (0, 3) == spritesToIconsService.cut(
            'tests/resources/sprites_to_icons/few',
            'regular'
        )

        capsys.readouterr()

    def test_cut_no_names(self, capsys):
        nameFromNumberService = NameFromNumberService('config.test.ini')
        nameFromNumberService.load('tests/resources/sprites_to_icons/empty.csv')
        spriteToIconService = SpriteToIconService('config.test.ini', nameFromNumberService)
        spritesToIconsService = SpritesToIconsService('config.test.ini', spriteToIconService)
        
        assert (0, 10) == spritesToIconsService.cut(
            'tests/resources/sprites_to_icons/some',
            'regular'
        )

        capsys.readouterr()

    def test_cut_names_not_loaded(self, capsys):
        spritesToIconsService = SpritesToIconsService(
            'config.test.ini', 
            SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
        )
        
        with pytest.raises(Exception) as e:
            spritesToIconsService.cut(
                'tests/resources/sprites_to_icons/some',
                'regular'
            )

        capsys.readouterr()

    def test_cut_non_existing_dir(self):
        spritesToIconsService = SpritesToIconsService(
                'config.test.ini', 
                SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
            )
        
        assert (0, 0) == spritesToIconsService.cut('/nexiste/pas', 'regular')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            SpritesToIconsService(
                'nexiste.pas.ini', 
                SpriteToIconService('config.test.ini', NameFromNumberService('config.test.ini'))
            ) 
    
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