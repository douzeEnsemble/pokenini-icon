import os

from pathlib import Path

from wand.image import Image
from wand.drawing import Drawing
from wand.color import Color

from module.Entity.Config.Config import Config

class RenameIconService:
    def __init__(self, configFile = 'config.ini'):
        self.config = Config(configFile)

    def rename(self, iconFile, newFileName):
        iconFilePath = Path(iconFile)
        newIconFile = iconFile.replace(iconFilePath.name, newFileName+iconFilePath.suffix)

        os.rename(iconFile, newIconFile)