import os

from pathlib import Path

from module.Entity.Config.Config import Config
from module.Util.FileDir import FileDir

class CleanTempFilesService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def clean(self):
        FileDir.removeDir(self.__dir().clean_icon_dir)
        FileDir.removeDir(self.__dir().cropped_sprite_dir)
        FileDir.removeDir(self.__dir().number_dir)
        FileDir.removeDir(self.__dir().split_sprite_dir)

        os.remove('temp/image.png')

    def __dir(self):
        return self.config.directories