import os
import csv

from module.Entity.Config.Config import Config

class CompareDirToListService:

    def __init__(self, configFile):
        self.config = Config(configFile)
        self.iconList = []
        self.pokemonList = []

    def compare(self, iconsDir, listFile):
        self.__loadIconList(iconsDir)
        self.__loadCsv(listFile)

        result = [
            pokemon for pokemon in self.pokemonList 
            if pokemon+'.png' not in self.iconList
        ]

        return result

    def __loadCsv(self, listFile):
        self.pokemonList = []

        with open(listFile, newline = '') as csvFile:
            spamreader = csv.reader(csvFile, delimiter=',', quotechar='"')
            for row in spamreader:
                if row[1] not in self.pokemonList:
                    self.pokemonList.append(row[1])

    def __loadIconList(self, iconsDir):
        self.iconList = os.listdir(iconsDir)
