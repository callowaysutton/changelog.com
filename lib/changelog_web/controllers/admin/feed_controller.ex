defmodule ChangelogWeb.Admin.FeedController do
  use ChangelogWeb, :controller

  alias Changelog.{Feed, Podcast}
  alias Changelog.ObanWorkers.FeedUpdater

  plug :assign_feed when action in [:edit, :update, :delete, :refresh]
  plug :assign_podcasts when action in [:index, :new, :create, :edit, :update]
  plug Authorize, [Policies.Admin.Feed, :feed]
  plug :scrub_params, "feed" when action in [:create, :update]

  def index(conn, params) do
    page =
      Feed
      |> Feed.newest_first()
      |> Feed.preload_all()
      |> Repo.paginate(params)

    conn
    |> assign(:page, page)
    |> render(:index)
  end

  def new(conn, _params) do
    changeset = Feed.insert_changeset(%Feed{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, params = %{"feed" => feed_params}) do
    changeset = Feed.insert_changeset(%Feed{}, feed_params)

    case Repo.insert(changeset) do
      {:ok, feed} ->
        Repo.update(Feed.file_changeset(feed, feed_params))

        conn
        |> put_flash(:result, "success")
        |> redirect_next(params, ~p"/admin/feeds/#{feed}/edit")

      {:error, changeset} ->
        conn
        |> put_flash(:result, "failure")
        |> render(:new, changeset: changeset)
    end
  end

  def edit(conn = %{assigns: %{feed: feed}}, _params) do
    changeset = Feed.update_changeset(feed)
    render(conn, :edit, feed: feed, changeset: changeset)
  end

  def update(conn = %{assigns: %{feed: feed}}, params = %{"feed" => feed_params}) do
    changeset = Feed.update_changeset(feed, feed_params)

    case Repo.update(changeset) do
      {:ok, feed} ->
        params = replace_next_edit_path(params, ~p"/admin/feeds/#{feed}/edit")

        conn
        |> put_flash(:result, "success")
        |> redirect_next(params, ~p"/admin/feeds")

      {:error, changeset} ->
        conn
        |> put_flash(:result, "failure")
        |> render(:edit, feed: feed, changeset: changeset)
    end
  end

  def delete(conn = %{assigns: %{feed: feed}}, _params) do
    Repo.delete!(feed)

    conn
    |> put_flash(:result, "success")
    |> redirect(to: ~p"/admin/feeds")
  end

  def refresh(conn = %{assigns: %{feed: feed}}, _params) do
    FeedUpdater.queue(feed)

    conn
    |> put_flash(:result, "success")
    |> redirect(to: ~p"/admin/feeds")
  end

  defp assign_feed(conn = %{params: %{"id" => id}}, _params) do
    feed = Feed |> Repo.get(id) |> Feed.preload_all()
    assign(conn, :feed, feed)
  end

  defp assign_podcasts(conn, _params) do
    podcasts =
      Podcast.active()
      |> Podcast.by_position()
      |> Repo.all()

    assign(conn, :podcasts, podcasts)
  end
end
