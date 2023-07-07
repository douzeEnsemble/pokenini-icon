class FilesConfig:
    
    def __init__(
        self, 
        cropped_image: str,
        output_numbered_dir_prefix: str,
    ):
        self.cropped_image = cropped_image
        self.output_numbered_dir_prefix = output_numbered_dir_prefix