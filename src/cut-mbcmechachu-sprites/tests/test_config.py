import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Entity.Config.Config import Config
from module.Entity.Config.ImageConfig import ImageConfig
from module.Entity.Config.SpriteFullConfig import SpriteFullConfig
from module.Entity.Config.SpriteNumberConfig import SpriteNumberConfig
from module.Entity.Config.SpriteIconConfig import SpriteIconConfig
from module.Entity.Config.SpriteIconDotConfig import SpriteIconDotConfig
from module.Entity.Config.DirectoriesConfig import DirectoriesConfig
from module.Entity.Config.FilesConfig import FilesConfig

class TestConfig:
    def test_init(self):
        config = Config('config.test.ini')

        assert 281 == config.image.paddingTop
        assert 0 == config.image.paddingLeft

        assert 69 == config.spriteFull.width
        assert 96 == config.spriteFull.height

        assert 61 == config.spriteNumber.width
        assert 9 == config.spriteNumber.height
        assert 16 == config.spriteNumber.top
        assert 7 == config.spriteNumber.left

        assert 68 == config.spriteIcon.width
        assert 68 == config.spriteIcon.height
        assert 27 == config.spriteIcon.top
        assert 1 == config.spriteIcon.left

        assert 5 == config.spriteIconDot.width
        assert 5 == config.spriteIconDot.height
        assert 0 == config.spriteIconDot.top
        assert 0 == config.spriteIconDot.left

        assert 'tests/resources/symbols/' == config.directories.symbols
        assert 'temp/test-sprites' == config.directories.cropped_sprite_dir
        assert 'temp/test-sprites-split' == config.directories.split_sprite_dir
        assert 'temp/test-number' == config.directories.number_dir
        assert 'temp/test-clean-icon' == config.directories.clean_icon_dir
        assert 'temp/test-final/small' == config.directories.final_base_dir

        assert 'temp/test-image.png' == config.files.cropped_image

class TestImageConfig:
    def test_init(self):
        imageConfig = ImageConfig(1, 2)

        assert 1 == imageConfig.paddingTop
        assert 2 == imageConfig.paddingLeft

class TestSpriteFullConfig:
    def test_init(self):
        spriteFullConfig = SpriteFullConfig(1, 2)

        assert 1 == spriteFullConfig.width
        assert 2 == spriteFullConfig.height

class TestSpriteNumberConfig:
    def test_init(self):
        spriteNumberConfig = SpriteNumberConfig(1, 2, 3, 4)

        assert 1 == spriteNumberConfig.width
        assert 2 == spriteNumberConfig.height
        assert 3 == spriteNumberConfig.top
        assert 4 == spriteNumberConfig.left

class TestSpriteIconConfig:
    def test_init(self):
        spriteIconConfig = SpriteIconConfig(1, 2, 3, 4)

        assert 1 == spriteIconConfig.width
        assert 2 == spriteIconConfig.height
        assert 3 == spriteIconConfig.top
        assert 4 == spriteIconConfig.left

class TestSpriteIconDotConfig:
    def test_init(self):
        spriteIconDotConfig = SpriteIconDotConfig(1, 2, 3, 4)

        assert 1 == spriteIconDotConfig.width
        assert 2 == spriteIconDotConfig.height
        assert 3 == spriteIconDotConfig.top
        assert 4 == spriteIconDotConfig.left

class TestDirectoriesConfig:
    def test_init(self):
        directories = DirectoriesConfig(
            '/dir/subdir/s/',
            '/dir/subdir/csd/',
            '/dir/subdir/ssd/',
            '/dir/subdir/nd/',
            '/dir/subdir/cid/',
            '/dir/subdir/fbd/'
        )

        assert '/dir/subdir/s/' == directories.symbols
        assert '/dir/subdir/csd/' == directories.cropped_sprite_dir
        assert '/dir/subdir/ssd/' == directories.split_sprite_dir
        assert '/dir/subdir/nd/' == directories.number_dir
        assert '/dir/subdir/cid/' == directories.clean_icon_dir
        assert '/dir/subdir/fbd/' == directories.final_base_dir

class TestFilesConfig:
    def test_init(self):
        files = FilesConfig(
            '/dir/subdir/ci.png',
        )

        assert '/dir/subdir/ci.png' == files.cropped_image