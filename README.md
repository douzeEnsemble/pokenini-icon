# Pokénini icons

## To Begin

### Webserver

#### Run

```
docker run -dit --name pokenini-icon -p 8082:80 -v "$PWD/images":/usr/local/apache2/htdocs/ httpd:2.4
```

#### Start

```
docker start pokenini-icon
```

#### Stop

```
docker stop pokenini-icon
```

### Scripts

Todo