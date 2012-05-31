var express = require('express');
var path = require('path');

var server = express.createServer();

server.use(express.favicon(path.join(__dirname, 'public/img/favicon.png')));

var stations = require('./lib/tlv')();

server.get('/tlv/stations', function(req, res) {
  return stations.all(function(err, stations) {
    if (err) return res.send(err);

    var arr = [];
    for (var id in stations) {
      var s = stations[id];
      s.url = '/tlv/stations/' + id;
      arr.push(s);
    }

    return res.send(arr);
  });
});

server.get('/tlv/stations/:id', function(req, res) {
  stations.one(req.params.id, function(err, station) {
    if (err) return res.send(err);
    return res.send(station);
  });
});

server.use(express.static(path.join(__dirname, 'public')));

server.listen(process.env.port || 5000);

console.log('telobike server started. listening on %s', process.env.port || 5000);
