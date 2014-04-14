### underlying data structures

# Hosted Websites
CREATE TABLE IF NOT EXISTS sites (
  `id` int(10) unsigned NOT NULL auto_increment,
  `expiration` date NOT NULL,
  `is_terminated` boolean NOT NULL default '0',
  # ...
  PRIMARY KEY (`id`)
);


CREATE TABLE IF NOT EXISTS announcements (
  `id` int(10) unsigned NOT NULL auto_increment,
  `category_id` int(10) unsigned NOT NULL,
  `creation` date NOT NULL,
  `content` text NOT NULL,
  # ...
  PRIMARY KEY (`id`)
);

# 
CREATE TABLE IF NOT EXISTS site_information (
  `id` int(10) unsigned NOT NULL auto_increment,
  `site_id` int(10) unsigned NOT NULL,
  # ...
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS categories (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(100) NOT NULL,
  # ...
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS category_entries (
  `category_id` int(10) unsigned NOT NULL,
  `creation` date NOT NULL,
  `entry` char(100) NOT NULL
  # ...
);

CREATE TABLE IF NOT EXISTS site_category_references (
  `category_id` int(10) unsigned NOT NULL,
  `site_id` int(10) unsigned NOT NULL
  # ...
);

# ...

### query
SELECT
  si.id, si.sites, si.refs, @refdate as qdate,
  ifnull(ac.entries / @window, @nodata) as event_density, if((ac.announcements / ac.entries) < @min_density, @defect, @ok) as announcements
FROM (SELECT
      @window:=50, @history:=731,
      @idx:=0, @category:=0, @nodata:=0.0,
      @defect:='missing', @ok:='ok',
      @refdate:=now(), @maxdate:=@refdate, @mindate:=@refdate - interval @history day
    ) options
  JOIN (
      SELECT c.id, c.name, count(distinct si.site_id) sites, count(distinct si.id) site_infos
      FROM categories c
        JOIN site_category_references scr ON c.id = scr.category_id
        JOIN site_information si ON scr.site_id = si.site_id
        JOIN sites s ON scr.site_id = s.id
      WHERE s.expiration > @refdate AND s.is_terminated = 0
      GROUP BY u.id
    ) si
  LEFT JOIN (
      SELECT
        ce.category_id, count(ce.entry) entries, count(an.content) announcements
      FROM (
          SELECT ifnull(@category:=category_id, 0) uid, min(creation) mindate, count(*) = @window valid
          FROM (SELECT category_id, creation FROM category_entries WHERE creation BETWEEN @mindate AND @maxdate ORDER BY category_id ASC, creation DESC) tmp
          WHERE (category_id != @category AND 0 = (SELECT if(@idx > 0, @idx:=0, @idx))) OR (@window > (SELECT @idx:=@idx+1) OR false)
          GROUP BY uid
        ) mindate
      JOIN category_entries ce ON ce.category_id = mindate.uid AND ce.creation between mindate.mindate AND @refdate
      LEFT JOIN announcements an ON ce.category_id = an.category_id AND ce.creation = an.creation
      GROUP BY ce.category_id
    ) ac ON si.id = ac.category_id
ORDER BY 7, 5 DESC;
