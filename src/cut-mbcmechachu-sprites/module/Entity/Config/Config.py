import configparser

from module.Entity.Config.ImageConfig import ImageConfig
from module.Entity.Config.SpriteFullConfig import SpriteFullConfig
from module.Entity.Config.SpriteNumberConfig import SpriteNumberConfig
from module.Entity.Config.SpriteIconConfig import SpriteIconConfig
from module.Entity.Config.SpriteIconDotConfig import SpriteIconDotConfig
from module.Entity.Config.DirectoriesConfig import DirectoriesConfig
from module.Entity.Config.FilesConfig import FilesConfig

class Config:

    def __init__(self, configFilePath: str):
        config = configparser.ConfigParser()
        config.read(configFilePath)

        self.image = ImageConfig(
            config['Image'].getint('padding_top'),
            config['Image'].getint('padding_left'),
        )

        self.spriteFull = SpriteFullConfig(
            config['Sprite'].getint('full_width'),
            config['Sprite'].getint('full_height'),
        )

        self.spriteNumber = SpriteNumberConfig(
            config['Sprite'].getint('number_width'),
            config['Sprite'].getint('number_height'),
            config['Sprite'].getint('number_top'),
            config['Sprite'].getint('number_left'),
        )

        self.spriteIcon = SpriteIconConfig(
            config['Sprite'].getint('icon_width'),
            config['Sprite'].getint('icon_height'),
            config['Sprite'].getint('icon_top'),
            config['Sprite'].getint('icon_left'),
        )

        self.spriteIconDot = SpriteIconDotConfig(
            config['Sprite'].getint('dot_width'),
            config['Sprite'].getint('dot_height'),
            config['Sprite'].getint('dot_top'),
            config['Sprite'].getint('dot_left'),
        )

        self.directories = DirectoriesConfig(
            config['Directories'].get('symbols'),
            config['Directories'].get('cropped_sprite_dir'),
            config['Directories'].get('split_sprite_dir'),
            config['Directories'].get('number_dir'),
            config['Directories'].get('clean_icon_dir'),
            config['Directories'].get('final_base_dir'),
        )

        self.files = FilesConfig(
            config['Files'].get('cropped_image'),
        )
