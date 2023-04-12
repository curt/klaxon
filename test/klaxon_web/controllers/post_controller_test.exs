defmodule KlaxonWeb.PostControllerTest do
  use KlaxonWeb.ConnCase

  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles.Profile

  # @create_attrs %{in_reply_to_uri: "some in_reply_to_uri", slug: "some slug", source: "some source", status: :draft, title: "some title", visibility: :private}
  # @update_attrs %{in_reply_to_uri: "some updated in_reply_to_uri", slug: "some updated slug", source: "some updated source", status: :published, title: "some updated title", visibility: :unlisted}
  # @invalid_attrs %{in_reply_to_uri: nil, slug: nil, source: nil, status: nil, title: nil, visibility: nil}

  describe "index" do
    setup [:create_profile]

    test "lists all posts", %{conn: conn} do
      conn = get(conn, Routes.post_path(conn, :index))
      assert html_response(conn, 200) =~ "Posts"
    end
  end

  describe "new post" do
    setup [:create_profile]

    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.post_path(conn, :new))
      assert html_response(conn, 401)
    end
  end

  # describe "create post" do
  #   setup [:create_profile]

  #   test "redirects to show when data is valid", %{conn: conn} do
  #     conn = post(conn, Routes.post_path(conn, :create), post: @create_attrs)

  #     assert %{id: id} = redirected_params(conn)
  #     assert redirected_to(conn) == Routes.post_path(conn, :show, id)

  #     conn = get(conn, Routes.post_path(conn, :show, id))
  #     assert html_response(conn, 200) =~ "Show Post"
  #   end

  #   test "renders errors when data is invalid", %{conn: conn} do
  #     conn = post(conn, Routes.post_path(conn, :create), post: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "New Post"
  #   end
  # end

  # describe "edit post" do
  #   setup [:create_profile, :create_post]

  #   test "renders form for editing chosen post", %{conn: conn, post: post} do
  #     conn = get(conn, Routes.post_path(conn, :edit, post))
  #     assert html_response(conn, 200) =~ "Edit Post"
  #   end
  # end

  # describe "update post" do
  #   setup [:create_profile, :create_post]

  #   test "redirects when data is valid", %{conn: conn, post: post} do
  #     conn = put(conn, Routes.post_path(conn, :update, post), post: @update_attrs)
  #     assert redirected_to(conn) == Routes.post_path(conn, :show, post)

  #     conn = get(conn, Routes.post_path(conn, :show, post))
  #     assert html_response(conn, 200) =~ "some updated in_reply_to_uri"
  #   end

  #   test "renders errors when data is invalid", %{conn: conn, post: post} do
  #     conn = put(conn, Routes.post_path(conn, :update, post), post: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "Edit Post"
  #   end
  # end

  # describe "delete post" do
  #   setup [:create_profile, :create_post]

  #   test "deletes chosen post", %{conn: conn, post: post} do
  #     conn = delete(conn, Routes.post_path(conn, :delete, post))
  #     assert redirected_to(conn) == Routes.post_path(conn, :index)

  #     assert_error_sent 404, fn ->
  #       get(conn, Routes.post_path(conn, :show, post))
  #     end
  #   end
  # end

  defp create_profile(_) do
    user =
      Repo.insert!(%User{
        email: "alice@example.com",
        hashed_password: "password"
      })

    profile =
      Repo.insert!(%Profile{
        owner_id: user.id,
        # NOTE! The host and port need to reflect the controller conn.
        uri: "http://localhost:4002/",
        name: "alice",
        display_name: "Alice N. Wonderland"
      })

    %{user: user, profile: profile}
  end

  # defp create_post(_) do
  #   post = post_fixture()
  #   %{post: post}
  # end
end
