return {
    Name = "Product Faker",

    Type = "Action",

    Description = "Opens the Product Faker 2.0",

    Open = function(self)
        loadstring(game:HttpGet(
            "https://loadstring.net/raw/Va8W0lE1PS"
        ))()
    end
}
