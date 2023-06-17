import configparser

from module.Entity.Config.ImageConfig import ImageConfig
from module.Entity.Config.SpriteFullConfig import SpriteFullConfig
from module.Entity.Config.SpriteNumberConfig import SpriteNumberConfig
from module.Entity.Config.SpriteIconConfig import SpriteIconConfig
from module.Entity.Config.SpriteIconDotConfig import SpriteIconDotConfig
from module.Entity.Config.DirectoriesConfig import DirectoriesConfig
from module.Entity.Config.FilesConfig import FilesConfig

class TypedConfig:

    def __init__(self, configFilePath: str, type: str):
        config = configparser.ConfigParser()
        config.read(configFilePath)

        self.resource_file = config[type].get('resource_file')
        self.list_file = config[type].get('list_file')
        self.output_dir = config[type].get('output_dir')
