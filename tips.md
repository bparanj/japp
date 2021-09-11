1. Reduce size of the image

```
RUN apt-get clean && rm -f /var/lib/apt/lists/*_*
```

2. Combine update, install and clean:

```
RUN apt-get update -y \
&& apt-get install -y -q package-name \
&& apt-get clean \
&& rm -f /var/lib/apt/lists/*_*
```

3. Use a separate build stage

```
FROM base-image AS builder
COPY . /app

RUN apt-get install build-essential \
&& bundle install --deployment

FROM base-image
COPY --from=builder /app /app
```

4. Set the system locale

```
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
&& locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
```

5. Create an unprivileged user.

# After build

```
RUN adduser -s /bin/sh -u 1001 -G root \
-h /app -S -D rails \
&& chown -R rails /app

USER rails
```

6. Prefer exec form for CMD

```
CMD ["bundle", "exec", "rails", "s"]
```

7. Specify resource constraints in production requests:

```
  memory: "100Mi"
  cpu: 0.5
 limits:
  memory: "200Mi"
  cpu: 1.0
```

8. Log to STDOUT or an external agent

```
ENV RAILS_LOG_STDOUT=true
```
