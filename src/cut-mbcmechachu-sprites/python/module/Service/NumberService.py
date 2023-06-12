import os

from pathlib import Path

from wand.image import Image
from wand.color import Color

from module.Entity.Config.Config import Config
from module.Service.BleachService import BleachService
from module.Service.CharacterRecognitionService import CharacterRecognitionService
from module.Util.FileDir import FileDir

class NumberService:

    def __init__(self, configFile):
        self.config = Config(configFile)
        self.bleachService = BleachService(configFile)
        self.characterRecognitionService = CharacterRecognitionService(configFile)

    def process(self, numberFile, targetDir):
        FileDir.createDirs(targetDir)

        numberFilePath = Path(numberFile)
        bleachedNumberFile = targetDir+'/bw_'+numberFilePath.name

        self.bleachService.bleach(numberFile, bleachedNumberFile)

        return self.characterRecognitionService.read(bleachedNumberFile)