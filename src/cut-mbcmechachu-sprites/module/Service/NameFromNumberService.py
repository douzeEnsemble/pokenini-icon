import csv

from module.Entity.Config.Config import Config

class NameFromNumberService:

    def __init__(self, configFile):
        self.config = Config(configFile)
        self.is_loaded = False
        self.data = {}

    def load(self, listFile):
        self.data = {}

        with open(listFile, newline = '') as csvFile:
            spamreader = csv.reader(csvFile, delimiter=',', quotechar='"')
            for row in spamreader:
                self.data[row[0]] = row[1]

        self.is_loaded = True
                

    def get(self, strNumber):
        if (not self.is_loaded):
            raise Exception("You need to load a file to be able to get data from") 
        
        if strNumber not in self.data:
            return ''
        
        return self.data[strNumber]