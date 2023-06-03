import os
import shutil

class FileDir:
    @staticmethod
    def countFiles(dir):
        count = 0
        for rootDir, curDir, files in os.walk(dir):
            count += len(files)

        return count
    
    @staticmethod
    def removeFiles(dir):
        if os.path.isdir(dir):
            shutil.rmtree(dir)

        os.mkdir(dir)