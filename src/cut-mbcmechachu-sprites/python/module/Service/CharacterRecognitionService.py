import os

from pathlib import Path

import cv2
import numpy as np

from module.Entity.Config.Config import Config

class CharacterRecognitionService:

    def __init__(self, configFile = 'config.ini'):
        self.config = Config(configFile)
        self.lettersPositions = {}

    def read(self, numberFile):
        self.lettersPositions = {}
        
        for rootDir, curDir, symbols in os.walk(self.config.directories.symbols):
            for symbol in symbols:
                self.__detect(numberFile, symbol)
        
        return self.__getNumberText__()
            
    def __detect(self, numberFile, symbol):
        symbolPath = Path(symbol)
        symbolFilename = symbolPath.name.replace(symbolPath.suffix, '')
        symbolName = self.__getSymbolName(symbolFilename)

        numberImage = cv2.imread(numberFile)
        symbolImage = cv2.imread(self.config.directories.symbols+symbol)

        result = cv2.matchTemplate(numberImage, symbolImage, cv2.TM_CCOEFF_NORMED)
        location = np.where(result >= 0.99)
        for point in location[1]:
            self.lettersPositions[point] = symbolName

    def __orderLetters__(self):
        keys = list(self.lettersPositions.keys())
        keys.sort()
        dict = {i: self.lettersPositions[i] for i in keys}
        self.lettersPositions = dict

    def __getNumberText__(self):
        self.__orderLetters__()

        txt = ''
        for char in self.lettersPositions.values():
            txt += char

        return txt

    def __getSymbolName(self, symbolFileName):
        match symbolFileName:
            case '7dm':
                return '7-'
            case 'dm_':
                return '-'
            case 'M_':
                return 'M'
            case 'dm':
                return '-'
            case 'qmqmqm':
                return '???'
            case _:
                return symbolFileName