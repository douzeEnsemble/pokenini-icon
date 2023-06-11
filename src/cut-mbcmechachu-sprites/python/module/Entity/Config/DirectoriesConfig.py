class DirectoriesConfig:
    
    def __init__(
        self, 
        symbols: str,
        cropped_image: str,
        cropped_sprite_dir: str,
        split_sprite_dir: str,
        number_dir: str,
        clean_icon_dir: str,
        final_base_dir: str
    ):
        self.symbols = symbols
        self.cropped_image = cropped_image
        self.cropped_sprite_dir = cropped_sprite_dir
        self.split_sprite_dir = split_sprite_dir
        self.number_dir = number_dir
        self.clean_icon_dir = clean_icon_dir
        self.final_base_dir = final_base_dir