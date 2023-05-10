import configparser

from module.Entity.Config.SpritesConfig import SpritesConfig
from module.Entity.Config.SpriteFullConfig import SpriteFullConfig
from module.Entity.Config.SpriteNumberConfig import SpriteNumberConfig
from module.Entity.Config.SpriteIconConfig import SpriteIconConfig

class Config:

    def __init__(self, configFilePath: str):
        config = configparser.ConfigParser()
        config.read(configFilePath)

        self.sprites = SpritesConfig(
            config['Sprites'].getint('padding_top'),
            config['Sprites'].getint('padding_left')
        )

        self.spriteFull = SpriteFullConfig(
            config['Sprite'].getint('full_width'),
            config['Sprite'].getint('full_height')
        )

        self.spriteNumber = SpriteNumberConfig(
            config['Sprite'].getint('number_width'),
            config['Sprite'].getint('number_height'),
            config['Sprite'].getint('number_top'),
            config['Sprite'].getint('number_left')
        )

        self.spriteIcon = SpriteIconConfig(
            config['Sprite'].getint('icon_width'),
            config['Sprite'].getint('icon_height'),
            config['Sprite'].getint('icon_top'),
            config['Sprite'].getint('icon_left')
        )
