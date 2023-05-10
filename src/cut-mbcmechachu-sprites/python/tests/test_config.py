import pytest
import sh

import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Entity.Config.Config import Config
from module.Entity.Config.SpritesConfig import SpritesConfig
from module.Entity.Config.SpriteFullConfig import SpriteFullConfig
from module.Entity.Config.SpriteNumberConfig import SpriteNumberConfig
from module.Entity.Config.SpriteIconConfig import SpriteIconConfig

class TestConfig:
    def test_init(self):
        config = Config('config.test.ini')

        assert 81 == config.sprites.paddingTop
        assert 2 == config.sprites.paddingLeft

        assert 69 == config.spriteFull.width
        assert 97 == config.spriteFull.height

        assert 61 == config.spriteNumber.width
        assert 10 == config.spriteNumber.height
        assert 16 == config.spriteNumber.top
        assert 8 == config.spriteNumber.left

        assert 68 == config.spriteIcon.width
        assert 68 == config.spriteIcon.height
        assert 28 == config.spriteIcon.top
        assert 1 == config.spriteIcon.left

class TestSpritesConfig:
    def test_init(self):
        spritesConfig = SpritesConfig(1, 2)

        assert 1 == spritesConfig.paddingTop
        assert 2 == spritesConfig.paddingLeft

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