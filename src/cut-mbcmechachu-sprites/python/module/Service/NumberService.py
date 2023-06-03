import os

from pathlib import Path

from wand.image import Image
from wand.color import Color

from module.Entity.Config.Config import Config
from module.Service.BleachService import BleachService
from module.Service.CharacterRecognitionService import CharacterRecognitionService

class NumberService:

    def __init__(self, configFile = 'config.ini'):
        self.config = Config(configFile)
        self.bleachService = BleachService('config.test.ini')
        self.characterRecognitionService = CharacterRecognitionService('config.test.ini')

    def process(self, numberFile):
        numberFilePath = Path(numberFile)
        bleachedNumberFile = numberFile.replace(numberFilePath.name, 'bw_'+numberFilePath.name)

        self.bleachService.bleach(numberFile, bleachedNumberFile)

        return self.characterRecognitionService.read(bleachedNumberFile)